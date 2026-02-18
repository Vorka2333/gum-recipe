MedLogs = {}

local fileBuffer = {}

local function flushFileBuffer()
    if not Config.Logging.SaveToFile or #fileBuffer == 0 then return end
    local existing = LoadResourceFile(GetCurrentResourceName(), Config.Logging.FilePath) or ''
    local payload = table.concat(fileBuffer, '\n') .. '\n'
    SaveResourceFile(GetCurrentResourceName(), Config.Logging.FilePath, existing .. payload, -1)
    fileBuffer = {}
end

CreateThread(function()
    while true do
        Wait((Config.Logging.FileFlushIntervalSec or 15) * 1000)
        flushFileBuffer()
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    flushFileBuffer()
end)

local function appendFile(line)
    if not Config.Logging.SaveToFile then return end
    fileBuffer[#fileBuffer + 1] = line
    if #fileBuffer >= (Config.Logging.FileFlushBatchSize or 25) then
        flushFileBuffer()
    end
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
        for _, playerId in ipairs(GetPlayers()) do
            local src = tonumber(playerId)
            if src and MedIsAdmin and MedIsAdmin(src) then
                TriggerClientEvent('vorp:TipBottom', src, msg, 5000)
            end
        end
    end
end
