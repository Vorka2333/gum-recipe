Locales = {}

local fallback = 'en'

local function loadLocale(locale)
    local path = ('locales/%s.lua'):format(locale)
    local chunk = LoadResourceFile(GetCurrentResourceName(), path)
    if not chunk then return {} end
    local fn = load(chunk, ('@@%s/%s'):format(GetCurrentResourceName(), path), 't', {})
    if not fn then return {} end
    local ok, data = pcall(fn)
    if not ok or type(data) ~= 'table' then return {} end
    return data
end

local current = loadLocale(Config.Locale)
local defaultTable = loadLocale(fallback)

function _L(key, ...)
    local text = current[key] or defaultTable[key] or key
    if select('#', ...) > 0 then
        return text:format(...)
    end
    return text
end
