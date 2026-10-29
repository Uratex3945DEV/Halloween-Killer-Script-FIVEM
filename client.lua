local active = false

local function loadModel(model)
    RequestModel(model)
    local t = GetGameTimer()
    while not HasModelLoaded(model) do
        Wait(10)
        if GetGameTimer() - t > 5000 then return false end
    end
    return true
end

local function getSpawnCoords(playerPed)
    -- on essaie plusieurs angles pour trouver un sol valide
    for _ = 1, 10 do
        local angle = math.random() * 2 * math.pi
        local x = GetEntityCoords(playerPed).x + math.cos(angle) * Config.SpawnDistance
        local y = GetEntityCoords(playerPed).y + math.sin(angle) * Config.SpawnDistance
        local z = GetEntityCoords(playerPed).z + 5.0
        local found, groundZ = GetGroundZFor_3dCoord(x, y, z, false)
        if found then
            return vector3(x, y, groundZ)
        end
    end
    return GetOffsetFromEntityInWorldCoords(playerPed, 0.0, -Config.SpawnDistance, 0.0)
end

local function cleanupPed(ped)
    if ped and DoesEntityExist(ped) then
        SetEntityAsMissionEntity(ped, true, true)
        DeletePed(ped)
    end
end

-- Spawn d'un Cerberus (local) derrière le véhicule du joueur
local function spawnCerberus(veh)
    local model = Config.CerberusModel
    if not IsModelInCdimage(model) or not IsModelAVehicle(model) then return nil end
    if not loadModel(model) then return nil end
    local pos = GetOffsetFromEntityInWorldCoords(veh, 0.0, -Config.CerberusDistance, 0.0)
    local found, gz = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 5.0, false)
    local z = found and gz or pos.z
    local cer = CreateVehicle(model, pos.x, pos.y, z, GetEntityHeading(veh), false, false)
    SetModelAsNoLongerNeeded(model)
    if not cer or cer == 0 then return nil end
    SetEntityAsMissionEntity(cer, true, true)
    SetVehicleOnGroundProperly(cer)
    SetVehicleEngineOn(cer, true, true, false)
    return cer
end

local function cleanupVehicle(veh)
    if veh and DoesEntityExist(veh) then
        SetEntityAsMissionEntity(veh, true, true)
        DeleteVehicle(veh)
    end
end

local function startKiller(noWeapon)
    if active then return end
    active = true

    local playerPed = PlayerPedId()
    if IsEntityDead(playerPed) then active = false return end

    if not loadModel(Config.PedModel) then active = false return end

    local coords = getSpawnCoords(playerPed)
    -- ped local (non réseau) : visible uniquement par le joueur ciblé
    local killer = CreatePed(4, Config.PedModel, coords.x, coords.y, coords.z, 0.0, false, false)
    SetModelAsNoLongerNeeded(Config.PedModel)

    -- Config du ped
    SetEntityAsMissionEntity(killer, true, true)
    SetEntityVisible(killer, true, false)
    ResetEntityAlpha(killer)
    SetPedMaxHealth(killer, Config.PedHealth)
    SetEntityHealth(killer, Config.PedHealth)
    SetPedArmour(killer, 0)
    GiveWeaponToPed(killer, Config.Weapon, 1, false, true)
    SetCurrentPedWeapon(killer, Config.Weapon, true)
    SetPedDropsWeaponsWhenDead(killer, false)
    SetPedCombatAttributes(killer, 46, true)  -- toujours combattre
    SetPedCombatAttributes(killer, 5, true)
    SetPedCombatMovement(killer, 3)
    SetPedCombatRange(killer, 0)
    SetPedFleeAttributes(killer, 0, false)
    SetBlockingOfNonTemporaryEvents(killer, true)
    SetPedKeepTask(killer, true)
    SetPedMoveRateOverride(killer, Config.RunSpeed)
    SetPedRelationshipGroupHash(killer, `HATES_PLAYER`)
    SetPedAsEnemy(killer, true)
    TaskCombatPed(killer, playerPed, 0, 16)

    -- Notification + son
    lib.notify({
        title = '🎃 Halloween',
        description = noWeapon and 'Cours ! Tu ne peux pas sortir d\'arme !' or 'Cours ! Une personne veut te tuer !',
        type = 'error',
        duration = 5000,
    })
    PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
    AnimpostfxPlay('Rampage', 0, true)

    local endTime = GetGameTimer() + Config.Duration * 1000
    local lastTask, lastHit = 0, 0
    local cerberus, targetVeh = nil, nil
    local exploding, exploded, explodeStart = false, false, 0
    local result = 'survived'

    while true do
        Wait(0)
        local remaining = math.max(0, math.ceil((endTime - GetGameTimer()) / 1000))

        -- Affichage du chrono
        SetTextFont(4)
        SetTextScale(0.0, 0.7)
        SetTextColour(255, 60, 0, 255)
        SetTextOutline()
        SetTextCentre(true)
        BeginTextCommandDisplayText('STRING')
        AddTextComponentSubstringPlayerName(('🎃 SURVIS : %ds'):format(remaining))
        EndTextCommandDisplayText(0.5, 0.05)

        -- Mode sans arme : impossible de sortir une arme
        if noWeapon then
            local pp = PlayerPedId()
            if GetSelectedPedWeapon(pp) ~= `WEAPON_UNARMED` then
                SetCurrentPedWeapon(pp, `WEAPON_UNARMED`, true)
            end
            DisableControlAction(0, 37, true)   -- roue des armes
            DisableControlAction(0, 157, true)  -- slots 1-5
            DisableControlAction(0, 158, true)
            DisableControlAction(0, 160, true)
            DisableControlAction(0, 164, true)
            DisableControlAction(0, 165, true)
            DisableControlAction(0, 99, true)   -- arme suivante / précédente
            DisableControlAction(0, 100, true)
            DisableControlAction(0, 115, true)
            DisableControlAction(0, 116, true)
            DisableControlAction(0, 261, true)
            DisableControlAction(0, 262, true)
            DisableControlAction(0, 25, true)   -- viser
        end

        -- Le tueur est mort
        if not DoesEntityExist(killer) or IsEntityDead(killer) then
            result = 'killed_ped'
            break
        end

        -- Le joueur est mort
        if IsEntityDead(PlayerPedId()) then
            result = 'died'
            break
        end

        -- Temps écoulé
        if remaining <= 0 then
            result = 'survived'
            break
        end

        -- Le tueur sprinte sur le joueur puis le poignarde jusqu'à la mort
        local pPed = PlayerPedId()
        local now = GetGameTimer()
        -- Joueur en véhicule : un Cerberus arrive et le véhicule explose
        if Config.VehicleExplosion then
            DisableControlAction(0, 23, true)  -- impossible de remonter dans un véhicule
            local veh = GetVehiclePedIsIn(pPed, false)
            if veh ~= 0 and not exploding and not exploded then
                exploding = true
                explodeStart = now
                targetVeh = veh
                cerberus = spawnCerberus(veh)
                if cerberus then
                    SetPedIntoVehicle(killer, cerberus, -1)
                    SetDriverAbility(killer, 1.0)
                    SetDriverAggressiveness(killer, 1.0)
                    TaskVehicleChase(killer, pPed)
                    SetPedKeepTask(killer, true)
                end
            end
            if exploding and not exploded then
                local close = false
                if cerberus and DoesEntityExist(cerberus) and DoesEntityExist(targetVeh) then
                    close = #(GetEntityCoords(cerberus) - GetEntityCoords(targetVeh)) < Config.ExplodeDistance
                end
                if close or not cerberus or now - explodeStart > Config.ExplodeTimeout then
                    exploded = true
                    exploding = false
                    if DoesEntityExist(targetVeh) then
                        local vc = GetEntityCoords(targetVeh)
                        AddExplosion(vc.x, vc.y, vc.z, 7, 10.0, true, false, 1.0)
                        NetworkExplodeVehicle(targetVeh, true, false, false)
                    end
                    -- le tueur descend du Cerberus et achève le joueur à pied
                    if cerberus and IsPedInAnyVehicle(killer, false) then
                        TaskLeaveVehicle(killer, cerberus, 16)
                        Wait(100)
                    end
                end
            end
        end

        local dist = #(GetEntityCoords(killer) - GetEntityCoords(pPed))
        if exploding then
            -- le tueur conduit le Cerberus
        elseif dist > Config.AttackDistance then
            if now - lastTask > 500 then
                lastTask = now
                TaskGoToEntity(killer, pPed, -1, 1.0, Config.GoToSpeed, 1073741824.0, 0)
                SetPedMoveRateOverride(killer, Config.RunSpeed)
            end
        else
            if not IsPedInCombat(killer, pPed) then
                TaskCombatPed(killer, pPed, 0, 16)
            end
            if now - lastHit > Config.HitInterval then
                lastHit = now
                ApplyDamageToPed(pPed, Config.HitDamage, false)
            end
        end
    end

    AnimpostfxStop('Rampage')

    if result == 'killed_ped' then
        lib.notify({ title = '🎃 Halloween', description = 'Tu as éliminé le tueur !', type = 'success' })
    elseif result == 'survived' then
        lib.notify({ title = '🎃 Halloween', description = 'Tu as survécu... le tueur disparaît dans la nuit.', type = 'success' })
    else
        lib.notify({ title = '🎃 Halloween', description = 'Le tueur t\'a eu...', type = 'error' })
    end

    -- Le ped disparaît (corps retiré après 3 s s'il est mort)
    if result == 'killed_ped' then Wait(3000) end
    cleanupPed(killer)
    cleanupVehicle(cerberus)
    active = false
end

RegisterNetEvent('halloween_killer:start', function() startKiller(false) end)
RegisterNetEvent('halloween_killer:startNoWeapon', function() startKiller(true) end)
