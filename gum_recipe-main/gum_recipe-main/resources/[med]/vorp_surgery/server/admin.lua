local function contains(list, value)
    for _, v in ipairs(list) do
        if v == value then return true end
    end
    return false
end

local function getVorpGroup(src)
    if not exports.vorp_core or not exports.vorp_core.GetUser then
        return nil
    end

    local User = exports.vorp_core:GetUser(src)
    if not User then return nil end

    local Character = User.getUsedCharacter and User.getUsedCharacter
    if type(Character) == 'function' then
        local c = User:getUsedCharacter()
        if type(c) == 'table' then
            return c.group or c.role
        end
    elseif type(Character) == 'table' then
        return Character.group or Character.role
    end

    return User.group or User.role
end

function MedIsAdmin(src)
    local mode = Config.Admin.Mode or 'both'
    local aceAllowed = IsPlayerAceAllowed(src, Config.Admin.GroupAce)
    local group = getVorpGroup(src)
    local vorpAllowed = group and contains(Config.Admin.AllowedVorpGroups or {}, tostring(group):lower()) or false

    if mode == 'vorp' then
        return vorpAllowed or aceAllowed
    elseif mode == 'ace' then
        return aceAllowed
    end

    return vorpAllowed or aceAllowed
end

local function notify(src, text)
    TriggerClientEvent('vorp:TipBottom', src, text, 4000)
end

RegisterCommand('meddebug', function(source, args)
    if source > 0 and not MedIsAdmin(source) then return end

    local target = tonumber(args[1]) or source
    local charId = MedInjuries.ensureLoadedBySource(target)
    if not charId then
        if source > 0 then notify(source, _L('no_target')) end
        return
    end

    local state = MedInjuries.getState(charId)
    local injuries = MedInjuries.getInjuries(charId)
    local payload = { charId = charId, state = state, injuries = injuries }

    if source > 0 then
        notify(source, _L('meddebug_header', GetPlayerName(target) or tostring(target)))
        TriggerClientEvent('chat:addMessage', source, { args = { '^2MED', json.encode(payload) } })
    else
        print(json.encode(payload))
    end
end, false)

RegisterCommand('medclear', function(source, args)
    if source > 0 and not MedIsAdmin(source) then return end
    local target = tonumber(args[1])
    if not target then
        if source > 0 then notify(source, _L('no_target')) end
        return
    end

    local charId = MedInjuries.ensureLoadedBySource(target)
    if not charId then return end

    MedInjuries.clear(charId)
    MedLogs.write('info', 'admin_clear', { admin = source, target = target, charId = charId })
    if source > 0 then notify(source, _L('injuries_cleared')) end
end, false)

RegisterCommand('medset', function(source, args)
    if source > 0 and not MedIsAdmin(source) then return end

    local target = tonumber(args[1])
    local injuryType = args[2] or 'bullet'
    local zone = args[3] or 'thorax'
    local severity = tonumber(args[4]) or 25
    local cause = args[5] or 'admin'

    if not target then
        if source > 0 then notify(source, _L('no_target')) end
        return
    end

    local charId = MedInjuries.ensureLoadedBySource(target)
    if not charId then return end

    MedInjuries.addInjury(charId, {
        injury_type = injuryType,
        body_zone = zone,
        severity = severity,
        cause = cause,
        has_projectile = injuryType == 'bullet',
        projectile_type = injuryType == 'bullet' and 'bullet' or nil,
        fracture_type = injuryType == 'fracture' and 'simple' or nil,
        is_open_wound = injuryType ~= 'commotion'
    }, { by = source })

    MedLogs.write('info', 'admin_set', { admin = source, target = target, type = injuryType, zone = zone, severity = severity })
    if source > 0 then notify(source, _L('injury_added')) end
end, false)
