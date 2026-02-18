MedLogs = {}

local function appendFile(line)
    if not Config.Logging.SaveToFile then return end
    local existing = LoadResourceFile(GetCurrentResourceName(), Config.Logging.FilePath) or ''
    SaveResourceFile(GetCurrentResourceName(), Config.Logging.FilePath, existing .. line .. '\n', -1)
end

function MedLogs.write(level, action, payload)
    local entry = {
        ts = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        level = level,
        action = action,
        payload = payload
    }

    if Config.Logging.PrintToConsole then
        print(('[MED][%s] %s %s'):format(level, action, json.encode(payload or {})))
    end

    if Config.Logging.SaveToDb then
        MedDB.insertLog(level, action, payload)
    end

    appendFile(json.encode(entry))
end

function MedLogs.flagExploit(reason, payload)
    local msg = _L('admin_flagged', reason)
    MedLogs.write('warn', 'exploit_flag', { reason = reason, detail = payload })
    if Config.Logging.FlagAdminOnExploit then
        TriggerClientEvent('vorp:TipBottom', -1, msg, 5000)
    end
end
