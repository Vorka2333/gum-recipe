MedSurgery = {
    active = {},
    patientTable = {}
}

local REQUIRED_ORDER = {
    select_zone = 1,
    incision = 2,
    retractors = 3,
    forceps = 4,
    clamps = 5,
    sutures = 6,
    antiseptic = 7
}

local function getPlayerCoords(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function near(a, b, maxDistance)
    return #(a - b) <= maxDistance
end

local function onFixedTable(coords)
    for _, tbl in ipairs(Config.Tables.Fixed) do
        if #(coords - tbl.coords) <= tbl.radius then
            return tbl.id
        end
    end
    return nil
end

function MedSurgery.setPatientOnTable(source, isOn)
    local charId = MedInjuries.ensureLoadedBySource(source)
    if not charId then return end
    local coords = getPlayerCoords(source)
    if not coords then return end

    if isOn then
        local tableId = onFixedTable(coords)
        if tableId then
            MedSurgery.patientTable[charId] = tableId
        end
    else
        MedSurgery.patientTable[charId] = nil
    end
end

local function buildValidationResult(ok, reason)
    return { ok = ok, reason = reason }
end

local function hasRequiredSequence(actions)
    local reached = 0
    local selectedZone
    local hasClamped = false
    local hasDisinfected = false
    local hasForceps = false

    for _, action in ipairs(actions) do
        local key = action.tool
        if key == 'select_zone' then
            selectedZone = action.zone
            reached = math.max(reached, REQUIRED_ORDER.select_zone)
        elseif key == 'incision' and reached >= REQUIRED_ORDER.select_zone then
            reached = math.max(reached, REQUIRED_ORDER.incision)
        elseif key == 'retractors' and reached >= REQUIRED_ORDER.incision then
            reached = math.max(reached, REQUIRED_ORDER.retractors)
        elseif key == 'forceps' and reached >= REQUIRED_ORDER.retractors then
            hasForceps = true
            reached = math.max(reached, REQUIRED_ORDER.forceps)
        elseif key == 'clamps' and reached >= REQUIRED_ORDER.retractors then
            hasClamped = true
            reached = math.max(reached, REQUIRED_ORDER.clamps)
        elseif key == 'sutures' and reached >= REQUIRED_ORDER.retractors then
            reached = math.max(reached, REQUIRED_ORDER.sutures)
        elseif key == 'antiseptic' then
            hasDisinfected = true
            reached = math.max(reached, REQUIRED_ORDER.antiseptic)
        end
    end

    return reached >= REQUIRED_ORDER.sutures, selectedZone, hasClamped, hasDisinfected, hasForceps
end

function MedSurgery.validateStart(doctorSrc, patientSrc)
    local doctorChar = MedInjuries.ensureLoadedBySource(doctorSrc)
    local patientChar = MedInjuries.ensureLoadedBySource(patientSrc)
    if not doctorChar or not patientChar then
        return buildValidationResult(false, 'missing identifiers')
    end

    local doctorCoords = getPlayerCoords(doctorSrc)
    local patientCoords = getPlayerCoords(patientSrc)
    if not doctorCoords or not patientCoords or not near(doctorCoords, patientCoords, Config.Surgery.AllowedDistance) then
        return buildValidationResult(false, 'distance_check_failed')
    end

    if Config.Surgery.RequirePatientOnTable and not MedSurgery.patientTable[patientChar] then
        return buildValidationResult(false, 'patient_not_on_table')
    end

    local patientState = MedInjuries.getState(patientChar)
    local needsFractureTools = patientState.fracture_state and next(patientState.fracture_state) ~= nil
    local hasTools, missing = InventoryBridge.hasRequiredTools(doctorSrc, needsFractureTools)
    if not hasTools then
        return buildValidationResult(false, ('missing_%s'):format(missing))
    end

    return buildValidationResult(true)
end

function MedSurgery.start(doctorSrc, patientSrc)
    if MedSurgery.active[doctorSrc] then
        return false, 'doctor_already_busy'
    end

    local val = MedSurgery.validateStart(doctorSrc, patientSrc)
    if not val.ok then
        return false, val.reason
    end

    local operationId = ('%d_%d_%d'):format(doctorSrc, patientSrc, os.time())
    MedSurgery.active[doctorSrc] = {
        operationId = operationId,
        doctorSrc = doctorSrc,
        patientSrc = patientSrc,
        startMs = GetGameTimer(),
        actions = {}
    }

    MedLogs.write('info', 'surgery_start', { operationId = operationId, doctor = doctorSrc, patient = patientSrc })
    return true, MedSurgery.active[doctorSrc]
end

function MedSurgery.cancel(doctorSrc, reason)
    local ctx = MedSurgery.active[doctorSrc]
    if not ctx then return end

    local patientChar = MedInjuries.ensureLoadedBySource(ctx.patientSrc)
    if patientChar then
        MedInjuries.applySurgeryResult(patientChar, {
            deltaPain = 6,
            deltaShock = 5,
            deltaHemorrhage = Config.Surgery.CancelOpenWoundBleed,
            deltaInfectionRisk = Config.Surgery.CancelInfectionRisk,
            openWound = true
        })
    end

    MedLogs.write('warn', 'surgery_cancel', { operationId = ctx.operationId, reason = reason })
    MedSurgery.active[doctorSrc] = nil
end

function MedSurgery.finalize(doctorSrc, payload)
    local ctx = MedSurgery.active[doctorSrc]
    if not ctx then
        return false, 'missing_context'
    end

    local duration = GetGameTimer() - ctx.startMs
    if duration < Config.Surgery.MinDurationMs or duration > Config.Surgery.MaxDurationMs then
        MedLogs.flagExploit('duration_invalid', { duration = duration, op = ctx.operationId })
        MedSurgery.active[doctorSrc] = nil
        return false, 'duration_invalid'
    end

    if type(payload.actions) ~= 'table' or #payload.actions == 0 or #payload.actions > Config.Surgery.MaxActions then
        MedLogs.flagExploit('action_log_invalid', { op = ctx.operationId })
        MedSurgery.active[doctorSrc] = nil
        return false, 'action_log_invalid'
    end

    local startVal = MedSurgery.validateStart(doctorSrc, ctx.patientSrc)
    if not startVal.ok then
        MedLogs.flagExploit('start_conditions_no_longer_valid', { reason = startVal.reason, op = ctx.operationId })
        MedSurgery.active[doctorSrc] = nil
        return false, startVal.reason
    end

    local coherent, zone, hasClamped, hasDisinfected, hasForceps = hasRequiredSequence(payload.actions)
    if not coherent then
        MedLogs.flagExploit('coherence_failed', { op = ctx.operationId })
        MedSurgery.active[doctorSrc] = nil
        return false, 'coherence_failed'
    end

    local patientChar = MedInjuries.ensureLoadedBySource(ctx.patientSrc)
    if not patientChar then
        MedSurgery.active[doctorSrc] = nil
        return false, 'patient_identifier_missing'
    end

    local injuries = MedInjuries.getInjuries(patientChar)
    local targetInjury
    for _, injury in ipairs(injuries) do
        if injury.body_zone == zone and not injury.is_treated then
            targetInjury = injury
            break
        end
    end

    local mistakes = tonumber(payload.errors) or 0
    local precision = tonumber(payload.precision) or 0.5

    local deltaHemorrhage = hasClamped and -18 or 9
    local deltaInfection = hasDisinfected and -16 or 12
    local deltaPain = math.floor(-12 + (mistakes * 2) - (precision * 6))
    local deltaShock = math.floor(-8 + mistakes)

    local openWound = true
    local projectileRemovedZone = nil

    if targetInjury then
        local newSeverity = MedUtils.clamp((targetInjury.severity or 20) - math.floor((precision * 20) - mistakes * 3), 1, 100)
        local treated = precision > 0.35 and mistakes < 9
        local stillProjectile = targetInjury.has_projectile and not hasForceps
        openWound = not treated

        MedDB.updateInjury(targetInjury.id, {
            severity = newSeverity,
            has_projectile = stillProjectile,
            is_treated = treated,
            treatment_note = treated and 'surgery_success' or 'surgery_partial',
            is_open_wound = openWound,
            metadata = { mistakes = mistakes, precision = precision, duration = duration }
        })

        targetInjury.severity = newSeverity
        targetInjury.is_treated = treated and 1 or 0
        targetInjury.has_projectile = stillProjectile
        targetInjury.is_open_wound = openWound
        if targetInjury.has_projectile and hasForceps then
            projectileRemovedZone = targetInjury.body_zone
        end
    else
        deltaPain = deltaPain + 8
        deltaShock = deltaShock + 6
        deltaHemorrhage = deltaHemorrhage + 10
        deltaInfection = deltaInfection + 6
    end

    local result = {
        deltaPain = deltaPain,
        deltaShock = deltaShock,
        deltaHemorrhage = deltaHemorrhage,
        deltaInfectionRisk = deltaInfection,
        openWound = openWound,
        projectileRemovedZone = projectileRemovedZone
    }

    MedInjuries.applySurgeryResult(patientChar, result)

    local doctorChar = MedInjuries.ensureLoadedBySource(doctorSrc)
    MedDB.insertTreatment(patientChar, doctorChar, {
        treatment_type = 'surgery',
        operation_log = payload.actions,
        result = result
    })

    MedLogs.write('info', 'surgery_finalize', {
        operationId = ctx.operationId,
        duration = duration,
        errors = mistakes,
        precision = precision,
        zone = zone,
        result = result
    })

    MedSurgery.active[doctorSrc] = nil
    return true, result
end
