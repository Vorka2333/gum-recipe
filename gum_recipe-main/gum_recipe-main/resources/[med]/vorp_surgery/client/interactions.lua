MedInteractions = {
    currentTable = nil,
    surgeryOpen = false,
    patientTarget = nil,
    isLayingOnTable = false
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

local function drawPrompt(text)
    SetTextScale(0.35, 0.35)
    SetTextFontForCurrentCommand(1)
    SetTextCentre(true)
    DisplayText(CreateVarString(10, 'LITERAL_STRING', text), 0.5, 0.86)
end

local function setLayState(enabled, tableDef)
    MedInteractions.isLayingOnTable = enabled
    TriggerServerEvent('med:server:setOnTable', enabled, tableDef and tableDef.id or nil)
    TriggerEvent('med:client:forceLayOnTable', tableDef, enabled)
end

CreateThread(function()
    while true do
        Wait(400)
        local tbl = nearestTable()
        if tbl then
            MedInteractions.currentTable = tbl
        else
            if MedInteractions.isLayingOnTable then
                setLayState(false)
            end
            MedInteractions.currentTable = nil
        end
    end
end)

CreateThread(function()
    while true do
        Wait(0)
        if MedInteractions.surgeryOpen then goto continue end

        local tableDef = MedInteractions.currentTable
        if tableDef then
            if Config.PatientTable.AllowPatientSelfLay then
                if MedInteractions.isLayingOnTable then
                    drawPrompt('[E] Se relever de la table')
                    if IsControlJustPressed(0, Config.PatientTable.PromptKeyLay) then
                        setLayState(false, tableDef)
                    end
                else
                    drawPrompt('[E] Se coucher sur la table')
                    if IsControlJustPressed(0, Config.PatientTable.PromptKeyLay) then
                        setLayState(true, tableDef)
                    end
                end
            end

            local target = nearestPlayer(2.8)
            if target then
                drawPrompt('[G] Lancer chirurgie  [H] Placer patient')
                if IsControlJustPressed(0, Config.PatientTable.PromptKeyStartSurgery) then
                    TriggerServerEvent('med:server:requestStartSurgery', target)
                end

                if Config.PatientTable.AllowDoctorPlace and IsControlJustPressed(0, Config.PatientTable.PromptKeyPlacePatient) then
                    TriggerServerEvent('med:server:placePatientOnTable', target, tableDef.id)
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
