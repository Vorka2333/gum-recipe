RegisterNetEvent('med:client:beginSurgery', function(payload)
    MedInteractions.surgeryOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'show',
        payload = {
            operationId = payload.operationId,
            hotkeys = Config.NUI.ToolHotkeys
        }
    })
end)

RegisterNUICallback('cancel', function(data, cb)
    TriggerServerEvent('med:server:cancelSurgery', data and data.reason or 'nui_cancel')
    cb({ ok = true })
end)

RegisterNUICallback('complete', function(data, cb)
    TriggerServerEvent('med:server:finalizeSurgery', {
        actions = data.actions or {},
        errors = tonumber(data.errors) or 0,
        precision = tonumber(data.precision) or 0
    })
    cb({ ok = true })
end)
