MedInjuries = {
    stateByChar = {},
    injuriesByChar = {},
    lastSaveByChar = {}
}

local function defaultState()
    return {
        pain = 0,
        shock = 0,
        hemorrhage = 0,
        infection_risk = 0,
        has_open_wound = false,
        sprint_abuse = 0,
        fracture_state = {},
        projectile_state = {}
    }
end

local function decodeOrEmpty(s)
    if not s or s == '' then return {} end
    local ok, value = pcall(json.decode, s)
    if not ok or type(value) ~= 'table' then return {} end
    return value
end

function MedInjuries.getCharIdentifier(source)
    local User = exports.vorp_core and exports.vorp_core:GetUser(source)
    if not User then return nil end
    local Character = User.getUsedCharacter and User.getUsedCharacter
    if type(Character) == 'function' then
        local c = User:getUsedCharacter()
        if c and c.charIdentifier then return tostring(c.charIdentifier) end
    elseif type(Character) == 'table' and Character.charIdentifier then
        return tostring(Character.charIdentifier)
    end
    return nil
end

function MedInjuries.ensureLoadedBySource(source)
    local charId = MedInjuries.getCharIdentifier(source)
    if not charId then return nil end
    if not MedInjuries.stateByChar[charId] then
        MedInjuries.loadPlayer(charId)
    end
    return charId
end

function MedInjuries.loadPlayer(charId)
    local row = MedDB.fetchPlayerState(charId)
    local state = defaultState()
    if row then
        state.pain = row.pain or 0
        state.shock = row.shock or 0
        state.hemorrhage = row.hemorrhage or 0
        state.infection_risk = row.infection_risk or 0
        state.has_open_wound = row.has_open_wound == 1
        state.sprint_abuse = row.sprint_abuse or 0
        state.fracture_state = decodeOrEmpty(row.fracture_state)
        state.projectile_state = decodeOrEmpty(row.projectile_state)
    end

    local injuries = MedDB.fetchInjuries(charId)
    MedInjuries.stateByChar[charId] = state
    MedInjuries.injuriesByChar[charId] = injuries or {}
    MedInjuries.lastSaveByChar[charId] = GetGameTimer()
end

function MedInjuries.savePlayer(charId, force)
    local state = MedInjuries.stateByChar[charId]
    if not state then return end

    local now = GetGameTimer()
    local last = MedInjuries.lastSaveByChar[charId] or 0
    if not force and (now - last) < Config.Injury.SaveThrottleMs then
        return
    end

    MedDB.upsertPlayerState(charId, state)
    MedInjuries.lastSaveByChar[charId] = now
end

function MedInjuries.addInjury(charId, injury, metadata)
    injury.severity = MedUtils.clamp(injury.severity or 15, Config.Injury.Severity.min, Config.Injury.Severity.max)
    injury.metadata = metadata or {}
    local id = MedDB.insertInjury(charId, injury)
    injury.id = id

    MedInjuries.injuriesByChar[charId] = MedInjuries.injuriesByChar[charId] or {}
    table.insert(MedInjuries.injuriesByChar[charId], 1, injury)

    local state = MedInjuries.stateByChar[charId] or defaultState()
    state.pain = MedUtils.clamp(state.pain + math.floor(injury.severity * 0.4), 0, 100)
    state.hemorrhage = MedUtils.clamp(state.hemorrhage + (injury.is_open_wound and 15 or 4), 0, 100)
    state.has_open_wound = state.has_open_wound or injury.is_open_wound
    if injury.injury_type == 'fracture' then
        state.fracture_state[injury.body_zone] = injury.fracture_type or 'simple'
    end
    if injury.has_projectile then
        state.projectile_state[injury.body_zone] = injury.projectile_type or 'unknown'
    end

    MedInjuries.stateByChar[charId] = state
    MedInjuries.savePlayer(charId, true)
    return injury
end

function MedInjuries.clear(charId)
    MedDB.clearInjuries(charId)
    MedInjuries.stateByChar[charId] = defaultState()
    MedInjuries.injuriesByChar[charId] = {}
end

function MedInjuries.getState(charId)
    return MedInjuries.stateByChar[charId] or defaultState()
end

function MedInjuries.getInjuries(charId)
    return MedInjuries.injuriesByChar[charId] or {}
end

function MedInjuries.applyProgression(charId, isSprinting)
    local state = MedInjuries.stateByChar[charId]
    if not state then return false end

    local before = json.encode(state)

    if state.has_open_wound then
        state.hemorrhage = MedUtils.clamp(state.hemorrhage + Config.Injury.OpenBleedTick, 0, 100)
    end

    if state.infection_risk > 0 and math.random(1, 100) <= Config.Injury.InfectionTickChance then
        state.pain = MedUtils.clamp(state.pain + 2, 0, 100)
        state.shock = MedUtils.clamp(state.shock + 1, 0, 100)
    end

    if isSprinting and state.has_open_wound then
        state.sprint_abuse = MedUtils.clamp(state.sprint_abuse + 1, 0, 100)
        state.hemorrhage = MedUtils.clamp(state.hemorrhage + Config.Injury.SprintAggravationTick, 0, 100)
    end

    if state.hemorrhage >= Config.Injury.ShockFromBleedThreshold then
        state.shock = MedUtils.clamp(state.shock + 2, 0, 100)
    end

    local after = json.encode(state)
    local changed = before ~= after
    if changed then
        MedInjuries.savePlayer(charId, false)
    end
    return changed
end

function MedInjuries.applySurgeryResult(charId, result)
    local state = MedInjuries.stateByChar[charId] or defaultState()
    state.pain = MedUtils.clamp((state.pain or 0) + result.deltaPain, 0, 100)
    state.shock = MedUtils.clamp((state.shock or 0) + result.deltaShock, 0, 100)
    state.hemorrhage = MedUtils.clamp((state.hemorrhage or 0) + result.deltaHemorrhage, 0, 100)
    state.infection_risk = MedUtils.clamp((state.infection_risk or 0) + result.deltaInfectionRisk, 0, 100)
    state.has_open_wound = result.openWound

    if result.projectileRemovedZone then
        state.projectile_state[result.projectileRemovedZone] = nil
    end

    MedInjuries.stateByChar[charId] = state
    MedInjuries.savePlayer(charId, true)
end
