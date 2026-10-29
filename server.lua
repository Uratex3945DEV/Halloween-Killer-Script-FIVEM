local ESX = exports['SpinFramework'] and exports['SpinFramework']:getSharedObject()
if not ESX then
    TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
end

local function isAdmin(src)
    if src == 0 then return true end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    local group = xPlayer.getGroup()
    for _, g in ipairs(Config.AdminGroups) do
        if g == group then return true end
    end
    return false
end

-- /killerhalloween [id | all]  et  /killerhalloweensansarme [id | all]
local function registerKillerCommand(name, event)
    RegisterCommand(name, function(source, args)
        if not isAdmin(source) then return end

        local target = args[1]
        if not target then
            if source == 0 then print(('Usage: %s [id|all]'):format(name)) end
            return
        end

        if target == 'all' then
            for _, id in ipairs(GetPlayers()) do
                TriggerClientEvent(event, tonumber(id))
            end
        else
            local id = tonumber(target)
            if id and GetPlayerName(id) then
                TriggerClientEvent(event, id)
            end
        end
    end, false)
end

registerKillerCommand('killerhalloween', 'halloween_killer:start')
registerKillerCommand('killerhalloweensansarme', 'halloween_killer:startNoWeapon')

-- Event aléatoire sur un joueur au hasard
CreateThread(function()
    if not Config.RandomEvent.enabled then return end
    while true do
        Wait(math.random(Config.RandomEvent.minMinutes, Config.RandomEvent.maxMinutes) * 60000)
        local players = GetPlayers()
        if #players > 0 then
            local id = tonumber(players[math.random(#players)])
            TriggerClientEvent('halloween_killer:start', id)
        end
    end
end)