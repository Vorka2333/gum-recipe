InventoryBridge = {
    ready = false,
    reason = nil
}

local function checkVorpInventory()
    if GetResourceState('vorp_inventory') ~= 'started' then
        return false, 'vorp_inventory not started'
    end
    if exports.vorp_inventory and exports.vorp_inventory.getItemCount then
        return true
    end
    return false, 'missing export getItemCount in vorp_inventory'
end

CreateThread(function()
    Wait(1000)
    local ok, reason = checkVorpInventory()
    InventoryBridge.ready = ok
    InventoryBridge.reason = reason
    if not ok and Config.Inventory.LogMissingBridgeAsError then
        print(_L('bridge_missing', reason))
    end
end)

function InventoryBridge.hasItem(source, itemName, amount)
    amount = amount or 1
    if not InventoryBridge.ready then
        return false, InventoryBridge.reason or 'bridge not ready'
    end

    local ok, count = pcall(function()
        return exports.vorp_inventory:getItemCount(source, nil, itemName)
    end)

    if not ok then
        return false, 'vorp_inventory getItemCount failed'
    end

    return (tonumber(count) or 0) >= amount, nil
end

function InventoryBridge.hasRequiredTools(source, requiresFracture)
    local list = MedUtils.deepcopy(Config.Inventory.RequiredBase)
    if requiresFracture then
        for _, item in ipairs(Config.Inventory.RequiredFracture) do
            list[#list + 1] = item
        end
    end

    for _, key in ipairs(list) do
        local itemName = Config.Inventory.Items[key] or key
        local ok = InventoryBridge.hasItem(source, itemName, 1)
        if not ok then
            return false, key
        end
    end

    return true
end
