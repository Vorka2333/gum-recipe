MedInteractions = {
    currentTable = nil,
    surgeryOpen = false,
    patientTarget = nil
}

local function nearestTable()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    for _, tbl in ipairs(Config.Tables.Fixed) do
        if #(coords - tbl.coords) <= tbl.radius then
            return tbl
        end
    end
    return nil
end

local function nearestPlayer(maxDistance)
    local players = GetActivePlayers()
    local me = PlayerId()
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local nearest, nearestDist

    for _, pid in ipairs(players) do
        if pid ~= me then
            local ped = GetPlayerPed(pid)
            local dist = #(GetEntityCoords(ped) - myCoords)
            if dist <= maxDistance and (not nearestDist or dist < nearestDist) then
                nearestDist = dist
                nearest = GetPlayerServerId(pid)
            end
        end
    end

    return nearest, nearestDist
end

CreateThread(function()
    while true do
        Wait(500)
        local tbl = nearestTable()
        if tbl and not MedInteractions.currentTable then
            MedInteractions.currentTable = tbl.id
            TriggerServerEvent('med:server:setOnTable', true)
        elseif not tbl and MedInteractions.currentTable then
            MedInteractions.currentTable = nil
            TriggerServerEvent('med:server:setOnTable', false)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(0)
        if MedInteractions.surgeryOpen then goto continue end
        if MedInteractions.currentTable then
            local target = nearestPlayer(2.8)
            if target then
                SetTextScale(0.35, 0.35)
                SetTextFontForCurrentCommand(1)
                SetTextCentre(true)
                DisplayText(CreateVarString(10, 'LITERAL_STRING', '[G] Lancer chirurgie'), 0.5, 0.86)
                if IsControlJustPressed(0, 0x760A9C6F) then -- G
                    TriggerServerEvent('med:server:requestStartSurgery', target)
                end
            end
        end
        ::continue::
    end
end)

RegisterNetEvent('med:client:surgeryDenied', function(msg)
    TriggerEvent('vorp:TipBottom', msg or _L('surgery_denied'), 5000)
end)

RegisterNetEvent('med:client:surgeryStarted', function(_doctor, _patient)
    TriggerEvent('vorp:TipBottom', _L('surgery_started'), 3000)
end)

RegisterNetEvent('med:client:surgeryResult', function(success, msg)
    MedInteractions.surgeryOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
    TriggerEvent('vorp:TipBottom', msg, success and 3000 or 5000)
end)

RegisterNetEvent('med:client:surgeryInterrupted', function()
    MedInteractions.surgeryOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
    TriggerEvent('vorp:TipBottom', _L('surgery_cancelled'), 5000)
end)
