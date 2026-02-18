MedUtils = {}

function MedUtils.now()
    return os.time()
end

function MedUtils.deepcopy(value)
    if type(value) ~= 'table' then
        return value
    end
    local copy = {}
    for k, v in pairs(value) do
        copy[k] = MedUtils.deepcopy(v)
    end
    return copy
end

function MedUtils.clamp(v, min, max)
    if v < min then return min end
    if v > max then return max end
    return v
end

function MedUtils.contains(list, value)
    for _, v in ipairs(list) do
        if v == value then return true end
    end
    return false
end
