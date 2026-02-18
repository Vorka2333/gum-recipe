CreateThread(function()
    MedDB.init()
    MedLogs.write('info', 'resource_start', { resource = GetCurrentResourceName(), version = '0.1.0-mvp' })
end)

local function pushStateToClient(source)
    local charId = MedInjuries.ensureLoadedBySource(source)
    if not charId then return end
    local state = MedInjuries.getState(charId)
    TriggerClientEvent('med:client:state', source, state)
end

AddEventHandler('playerJoining', function(playerId)
    local src = tonumber(playerId)
    SetTimeout(2000, function()
        local charId = MedInjuries.ensureLoadedBySource(src)
        if charId then
            pushStateToClient(src)
        end
    end)
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    for doctorSrc, ctx in pairs(MedSurgery.active) do
        if ctx.doctorSrc == src or ctx.patientSrc == src then
            MedSurgery.cancel(doctorSrc, ('disconnect:%s'):format(reason or 'unknown'))
            TriggerClientEvent('med:client:surgeryInterrupted', ctx.doctorSrc)
            TriggerClientEvent('med:client:surgeryInterrupted', ctx.patientSrc)
        end
    end
end)

RegisterNetEvent('med:server:setOnTable', function(isOn)
    local src = source
    MedSurgery.setPatientOnTable(src, isOn == true)
end)

RegisterNetEvent('med:server:requestStartSurgery', function(patientSrc)
    local src = source
    patientSrc = tonumber(patientSrc)
    if not patientSrc then
        TriggerClientEvent('med:client:surgeryDenied', src, _L('surgery_denied'))
        return
    end

    local ok, ctxOrReason = MedSurgery.start(src, patientSrc)
    if not ok then
        TriggerClientEvent('med:client:surgeryDenied', src, ctxOrReason)
        return
    end

    TriggerClientEvent('med:client:beginSurgery', src, { patient = patientSrc, operationId = ctxOrReason.operationId })
    TriggerClientEvent('med:client:setOperationImmobilized', patientSrc, true)
    TriggerClientEvent('med:client:surgeryStarted', src, patientSrc)
end)

RegisterNetEvent('med:server:cancelSurgery', function(reason)
    local src = source
    local ctx = MedSurgery.active[src]
    if not ctx then return end

    MedSurgery.cancel(src, reason or 'client_cancel')
    TriggerClientEvent('med:client:setOperationImmobilized', ctx.patientSrc, false)
    TriggerClientEvent('med:client:surgeryResult', src, false, _L('surgery_cancelled'))
end)

RegisterNetEvent('med:server:finalizeSurgery', function(payload)
    local src = source
    payload = payload or {}

    local ctx = MedSurgery.active[src]
    if not ctx then
        TriggerClientEvent('med:client:surgeryResult', src, false, _L('surgery_failed_validation'))
        return
    end

    local ok, resultOrReason = MedSurgery.finalize(src, payload)
    TriggerClientEvent('med:client:setOperationImmobilized', ctx.patientSrc, false)

    if not ok then
        TriggerClientEvent('med:client:surgeryResult', src, false, resultOrReason)
        return
    end

    TriggerClientEvent('med:client:surgeryResult', src, true, _L('surgery_success'))
    pushStateToClient(ctx.patientSrc)
end)

RegisterNetEvent('med:server:syncSprintState', function(isSprinting)
    local src = source
    local charId = MedInjuries.ensureLoadedBySource(src)
    if not charId then return end
    MedInjuries.applyProgression(charId, isSprinting == true)
    pushStateToClient(src)
end)

exports('addInjury', function(sourceOrCharIdentifier, injury)
    local charId
    if type(sourceOrCharIdentifier) == 'number' then
        charId = MedInjuries.ensureLoadedBySource(sourceOrCharIdentifier)
    else
        charId = tostring(sourceOrCharIdentifier)
        if not MedInjuries.stateByChar[charId] then
            MedInjuries.loadPlayer(charId)
        end
    end

    if not charId then return false, 'missing_char' end
    local saved = MedInjuries.addInjury(charId, injury)
    MedLogs.write('info', 'api_addInjury', { charId = charId, injury = injury })
    return true, saved
end)

exports('getMedicalState', function(sourceOrCharIdentifier)
    local charId
    if type(sourceOrCharIdentifier) == 'number' then
        charId = MedInjuries.ensureLoadedBySource(sourceOrCharIdentifier)
    else
        charId = tostring(sourceOrCharIdentifier)
    end
    if not charId then return nil end
    if not MedInjuries.stateByChar[charId] then
        MedInjuries.loadPlayer(charId)
    end
    return {
        state = MedInjuries.getState(charId),
        injuries = MedInjuries.getInjuries(charId)
    }
end)
