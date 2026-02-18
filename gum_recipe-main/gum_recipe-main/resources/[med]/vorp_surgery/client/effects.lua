MedEffects = {
    state = nil,
    sprintSeconds = 0,
    immobilized = false,
    clipsetApplied = false
}

RegisterNetEvent('med:client:state', function(state)
    MedEffects.state = state
end)

RegisterNetEvent('med:client:setOperationImmobilized', function(value)
    MedEffects.immobilized = value == true
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, MedEffects.immobilized)
    if MedEffects.immobilized then
        TaskStartScenarioInPlace(ped, `WORLD_HUMAN_SLEEP_GROUND_ARM`, -1, true, false, false, false)
    else
        ClearPedTasksImmediately(ped)
    end
end)

CreateThread(function()
    while true do
        Wait(Config.Effects.SyncIntervalSec * 1000)
        local ped = PlayerPedId()
        local sprinting = IsPedSprinting(ped)
        TriggerServerEvent('med:server:syncSprintState', sprinting)
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        local state = MedEffects.state
        if not state then goto continue end

        local ped = PlayerPedId()
        if state.pain >= Config.Effects.Stamina.severeThreshold or state.shock >= Config.Effects.Stamina.severeThreshold then
            RestorePlayerStamina(PlayerId(), 0.0)
            if Config.Effects.Blur.enabled then
                TriggerScreenblurFadeIn(200)
                SetTimeout(Config.Effects.Blur.pulseMs, function()
                    TriggerScreenblurFadeOut(250)
                end)
            end
        end

        if IsPedSprinting(ped) then
            MedEffects.sprintSeconds = MedEffects.sprintSeconds + 1
            if MedEffects.sprintSeconds >= Config.Effects.Sprint.maxContinuousSec and (state.has_open_wound or state.hemorrhage >= 30) then
                SetPedToRagdoll(ped, Config.Effects.Sprint.ragdollDurationMs, Config.Effects.Sprint.ragdollDurationMs, 0, true, true, false)
                MedEffects.sprintSeconds = 0
            end
        else
            MedEffects.sprintSeconds = 0
        end

        local legFracture = state.fracture_state and (state.fracture_state.leg_l or state.fracture_state.leg_r)
        if legFracture and not MedEffects.clipsetApplied then
            RequestAnimSet(Config.Effects.Fracture.legMoveClipset)
            while not HasAnimSetLoaded(Config.Effects.Fracture.legMoveClipset) do Wait(20) end
            SetPedMovementClipset(ped, Config.Effects.Fracture.legMoveClipset, 0.25)
            SetRunSprintMultiplierForPlayer(PlayerId(), Config.Effects.Fracture.speedMultiplier)
            MedEffects.clipsetApplied = true
        elseif not legFracture and MedEffects.clipsetApplied then
            ResetPedMovementClipset(ped, 0.35)
            SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
            MedEffects.clipsetApplied = false
        end

        ::continue::
    end
end)
