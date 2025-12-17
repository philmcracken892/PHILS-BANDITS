local RSGCore = exports['rsg-core']:GetCoreObject()

local spawnbandits = false
local calloffbandits = false
local cooldownSecondsRemaining = 0
local npcs = {}
local horse = {}
local banditBlips = {}
local trackedBandits = {} 

local adminSpawnedBandits = {}
local adminSpawnedHorses = {}
local adminBanditBlips = {}
local tempBanditLocations = {}
local copiedCoords = nil
local configBanditsEnabled = Config.EnableConfigBandits

-- Zombie tracking
local adminSpawnedZombies = {}
local adminZombieBlips = {}
local trackedZombies = {}

-- Track which locations we've already requested
local pendingConfigRequests = {}
local pendingProximityRequests = {}

-- Get spawn limits from config or use defaults
local function getSpawnLimits()
    return {
        banditsPerSpawn = (Config.SpawnLimits and Config.SpawnLimits.banditsPerSpawn) or 50,
        zombiesPerSpawn = (Config.SpawnLimits and Config.SpawnLimits.zombiesPerSpawn) or 100,
        totalBandits = (Config.SpawnLimits and Config.SpawnLimits.totalBandits) or 100,
        totalZombies = (Config.SpawnLimits and Config.SpawnLimits.totalZombies) or 200,
        hordeSize = (Config.SpawnLimits and Config.SpawnLimits.hordeSize) or 50,
    }
end

-- Get retarget settings from config or use defaults
local function getRetargetSettings()
    return {
        enabled = (Config.RetargetSettings and Config.RetargetSettings.enabled) ~= false,
        retargetRange = (Config.RetargetSettings and Config.RetargetSettings.retargetRange) or 150.0,
        retargetDelay = (Config.RetargetSettings and Config.RetargetSettings.retargetDelay) or 2000,
        aggroAllPlayersInRange = (Config.RetargetSettings and Config.RetargetSettings.aggroAllPlayersInRange) or false,
        checkInterval = (Config.RetargetSettings and Config.RetargetSettings.checkInterval) or 3000,
    }
end

-- ============================================
-- PLAYER TARGETING FUNCTIONS
-- ============================================

-- Get all players within range of a position
function GetPlayersInRange(coords, range)
    local players = {}
    local allPlayers = GetActivePlayers()
    
    for _, playerId in ipairs(allPlayers) do
        local playerPed = GetPlayerPed(playerId)
        if playerPed and DoesEntityExist(playerPed) and not IsPedDeadOrDying(playerPed, true) then
            local playerCoords = GetEntityCoords(playerPed)
            local distance = GetDistanceBetweenCoords(coords.x, coords.y, coords.z, playerCoords.x, playerCoords.y, playerCoords.z, true)
            if distance <= range then
                table.insert(players, {
                    id = playerId,
                    ped = playerPed,
                    distance = distance,
                    coords = playerCoords
                })
            end
        end
    end
    
    -- Sort by distance (closest first)
    table.sort(players, function(a, b)
        return a.distance < b.distance
    end)
    
    return players
end

-- Get the nearest alive player to a position
function GetNearestAlivePlayer(coords, range)
    local players = GetPlayersInRange(coords, range)
    if #players > 0 then
        return players[1].ped, players[1].distance
    end
    return nil, nil
end

-- Retarget a single entity to attack nearest player
function RetargetEntity(entity, range)
    if not DoesEntityExist(entity) or IsPedDeadOrDying(entity, true) then
        return false
    end
    
    local entityCoords = GetEntityCoords(entity)
    local settings = getRetargetSettings()
    local searchRange = range or settings.retargetRange
    
    if settings.aggroAllPlayersInRange then
        -- Attack all players in range
        local players = GetPlayersInRange(entityCoords, searchRange)
        if #players > 0 then
            -- Set primary target as closest player
            TaskCombatPed(entity, players[1].ped, 0, 16)
            return true
        end
    else
        -- Attack only the nearest player
        local nearestPlayer, distance = GetNearestAlivePlayer(entityCoords, searchRange)
        if nearestPlayer then
            TaskCombatPed(entity, nearestPlayer, 0, 16)
            return true
        end
    end
    
    return false
end

-- Retarget all bandits
function RetargetAllBandits()
    local settings = getRetargetSettings()
    local count = 0
    
    for _, bandit in pairs(adminSpawnedBandits) do
        if DoesEntityExist(bandit) and not IsPedDeadOrDying(bandit, true) then
            if RetargetEntity(bandit, settings.retargetRange) then
                count = count + 1
            end
        end
    end
    
    for _, npc in pairs(npcs) do
        if DoesEntityExist(npc) and not IsPedDeadOrDying(npc, true) then
            if RetargetEntity(npc, settings.retargetRange) then
                count = count + 1
            end
        end
    end
    
    return count
end

-- Retarget all zombies
function RetargetAllZombies()
    local settings = getRetargetSettings()
    local count = 0
    
    for _, zombie in pairs(adminSpawnedZombies) do
        if DoesEntityExist(zombie) and not IsPedDeadOrDying(zombie, true) then
            if RetargetEntity(zombie, settings.retargetRange) then
                count = count + 1
            end
        end
    end
    
    return count
end

-- Retarget all enemies (bandits + zombies)
function RetargetAllEnemies()
    local bandits = RetargetAllBandits()
    local zombies = RetargetAllZombies()
    return bandits + zombies
end

-- ============================================
-- CONTINUOUS TARGETING THREAD
-- ============================================
-- This thread continuously checks for player deaths and retargets enemies

Citizen.CreateThread(function()
    local lastPlayerState = {} -- Track player alive/dead states
    
    while true do
        local settings = getRetargetSettings()
        Wait(settings.checkInterval)
        
        if settings.enabled then
            local allPlayers = GetActivePlayers()
            local playerDied = false
            
            -- Check if any player just died
            for _, playerId in ipairs(allPlayers) do
                local playerPed = GetPlayerPed(playerId)
                local isDead = IsPedDeadOrDying(playerPed, true)
                local wasAlive = lastPlayerState[playerId] == false or lastPlayerState[playerId] == nil
                
                if isDead and wasAlive then
                    playerDied = true
                    print("[rsg-bandits] Player " .. playerId .. " died, triggering retarget")
                end
                
                lastPlayerState[playerId] = isDead
            end
            
            -- If a player died, wait a moment then retarget all enemies
            if playerDied then
                Wait(settings.retargetDelay)
                local retargeted = RetargetAllEnemies()
                if retargeted > 0 then
                    print("[rsg-bandits] Retargeted " .. retargeted .. " enemies to new players")
                end
            end
            
            -- Also periodically retarget enemies that have no target or lost their target
            if settings.aggroAllPlayersInRange then
                RetargetIdleEnemies()
            end
        end
    end
end)

-- Retarget enemies that are idle or have lost their target
function RetargetIdleEnemies()
    local settings = getRetargetSettings()
    
    -- Check admin spawned bandits
    for _, bandit in pairs(adminSpawnedBandits) do
        if DoesEntityExist(bandit) and not IsPedDeadOrDying(bandit, true) then
            -- Check if bandit is not in combat or has no target
            if not IsPedInCombat(bandit, 0) then
                RetargetEntity(bandit, settings.retargetRange)
            else
                -- Check if current target is dead
                local target = GetPedTaskCombatTarget(bandit, 0)
                if target == 0 or not DoesEntityExist(target) or IsPedDeadOrDying(target, true) then
                    RetargetEntity(bandit, settings.retargetRange)
                end
            end
        end
    end
    
    -- Check config bandits
    for _, npc in pairs(npcs) do
        if DoesEntityExist(npc) and not IsPedDeadOrDying(npc, true) then
            if not IsPedInCombat(npc, 0) then
                RetargetEntity(npc, settings.retargetRange)
            else
                local target = GetPedTaskCombatTarget(npc, 0)
                if target == 0 or not DoesEntityExist(target) or IsPedDeadOrDying(target, true) then
                    RetargetEntity(npc, settings.retargetRange)
                end
            end
        end
    end
    
    -- Check zombies
    for _, zombie in pairs(adminSpawnedZombies) do
        if DoesEntityExist(zombie) and not IsPedDeadOrDying(zombie, true) then
            if not IsPedInCombat(zombie, 0) then
                RetargetEntity(zombie, settings.retargetRange)
            else
                local target = GetPedTaskCombatTarget(zombie, 0)
                if target == 0 or not DoesEntityExist(target) or IsPedDeadOrDying(target, true) then
                    RetargetEntity(zombie, settings.retargetRange)
                end
            end
        end
    end
end

-- Helper function to get combat target
function GetPedTaskCombatTarget(ped, p1)
    return Citizen.InvokeNative(0xF9FC7AF4B07BD8F6, ped, Citizen.ReturnResultAnyway()) -- GET_PED_TARGET or similar
end

-- ============================================
-- RESOURCE START/PLAYER LOAD
-- ============================================

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    TriggerServerEvent('rsg-bandits:server:getSavedLocations')
end)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('rsg-bandits:server:getSavedLocations')
end)

RegisterNetEvent('rsg-bandits:client:loadSavedLocations', function(locations)
    for _, location in ipairs(tempBanditLocations) do
        if location.blip and DoesBlipExist(location.blip) then
            RemoveBlip(location.blip)
        end
    end
    
    tempBanditLocations = {}
    
    for _, loc in ipairs(locations) do
        table.insert(tempBanditLocations, {
            id = loc.id,
            coords = vector3(loc.coords.x, loc.coords.y, loc.coords.z),
            heading = loc.heading or 0.0,
            name = loc.name,
            spawnType = loc.spawnType or 'bandit',
            banditType = loc.banditType or 'mounted',
            banditCount = loc.banditCount or 3,
            zombieCount = loc.zombieCount or 0,
            timer = loc.timer or 0,
            proximity = loc.proximity or 0,
            initialDelay = loc.initialDelay or 60,
            cooldown = loc.cooldown or 300,
            createdAt = GetGameTimer(),
            isTriggered = false,
            lastTriggered = nil,
            enabled = loc.enabled ~= false,
            createdBy = loc.createdBy
        })
    end
    
    print("[rsg-bandits] Loaded " .. #tempBanditLocations .. " saved locations")
end)

-- Update config bandits toggle
RegisterNetEvent('rsg-bandits:client:updateConfigBandits', function(enabled)
    configBanditsEnabled = enabled
    if enabled then
        TriggerEvent('rNotify:NotifyLeft', "CONFIG BANDITS", "Enabled", "generic_textures", "tick", 4000)
    else
        TriggerEvent('rNotify:NotifyLeft', "CONFIG BANDITS", "Disabled", "generic_textures", "tick", 4000)
    end
end)

-- Config bandits trigger loop
Citizen.CreateThread(function()
    while true do
        Wait(1000)
        if configBanditsEnabled and Config.EnableConfigBandits then
            for v, k in pairs(Config.Bandits) do
                if k.enabled ~= false then
                    local coords = GetEntityCoords(PlayerPedId())
                    local dis = GetDistanceBetweenCoords(coords.x, coords.y, coords.z, k.triggerPoint.x, k.triggerPoint.y, k.triggerPoint.z)
                    
                    if dis < Config.TriggerBandits and spawnbandits == false then
                        if not pendingConfigRequests[v] then
                            pendingConfigRequests[v] = true
                            TriggerServerEvent('rsg-bandits:server:requestConfigTrigger', v)
                        end
                    else
                        pendingConfigRequests[v] = nil
                    end
                    
                    if dis >= Config.CalloffBandits and spawnbandits == true then
                        calloffbandits = true
                    end
                end
            end
        end
    end
end)

RegisterNetEvent('rsg-bandits:client:triggerConfigBandits', function(configIndex)
    local k = Config.Bandits[configIndex]
    if k and spawnbandits == false then
        banditsTrigger(k.bandits, k.mounted)
    end
    pendingConfigRequests[configIndex] = nil
end)

RegisterNetEvent('rsg-bandits:client:configTriggerDenied', function(configIndex, reason)
    pendingConfigRequests[configIndex] = nil
end)

function banditsTrigger(bandits, mounted)
    spawnbandits = true
    if mounted == nil then mounted = true end
    
    local settings = getRetargetSettings()
    
    for v, k in pairs(bandits) do
        local banditmodel = GetHashKey(Config.BanditsModel[math.random(1, #Config.BanditsModel)])
        local banditWeapon = Config.Weapons[math.random(1, #Config.Weapons)]
        
        RequestModel(banditmodel)
        if not HasModelLoaded(banditmodel) then RequestModel(banditmodel) end
        while not HasModelLoaded(banditmodel) do Wait(1) end
        Citizen.Wait(100)
        
        npcs[v] = CreatePed(banditmodel, k, true, true, true, true)
        Citizen.InvokeNative(0x283978A15512B2FE, npcs[v], true)
        Citizen.InvokeNative(0x23f74c2fda6e7c61, 953018525, npcs[v])
        
        GiveWeaponToPed(npcs[v], banditWeapon, 50, true, true, 1, false, 0.5, 1.0, 1.0, true, 0, 0)
        SetCurrentPedWeapon(npcs[v], banditWeapon, true)
        
        -- Enhanced combat attributes for better targeting
        SetPedCombatAttributes(npcs[v], 46, true)
        SetPedCombatAttributes(npcs[v], 5, true)
        SetPedFleeAttributes(npcs[v], 0, false)
        
        trackedBandits[npcs[v]] = {
            isDead = false,
            type = "config"
        }
        
        local banditCoords = GetEntityCoords(npcs[v])
        local banditBlip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, banditCoords.x, banditCoords.y, banditCoords.z)
        Citizen.InvokeNative(0x9CB1A1623062F402, banditBlip, mounted and "Mounted Bandit" or "Bandit")
        Citizen.InvokeNative(0x662D364ABF16DE2F, banditBlip, 0x59FA676C)
        banditBlips[v] = banditBlip
        
        if mounted then
            local horsemodel = GetHashKey(Config.HorseModels[math.random(1, #Config.HorseModels)])
            
            RequestModel(horsemodel)
            if not HasModelLoaded(horsemodel) then RequestModel(horsemodel) end
            while not HasModelLoaded(horsemodel) do Wait(1) end
            Citizen.Wait(100)
            
            horse[v] = CreatePed(horsemodel, k, true, true, true, true)
            Citizen.InvokeNative(0x283978A15512B2FE, horse[v], true)
            Citizen.InvokeNative(0xD3A7B003ED343FD9, horse[v], 0x20359E53, true, true, true)
            Citizen.InvokeNative(0xD3A7B003ED343FD9, horse[v], 0x508B80B9, true, true, true)
            Citizen.InvokeNative(0xD3A7B003ED343FD9, horse[v], 0xF0C30271, true, true, true)
            Citizen.InvokeNative(0xD3A7B003ED343FD9, horse[v], 0x12F0DF9F, true, true, true)
            Citizen.InvokeNative(0xD3A7B003ED343FD9, horse[v], 0x67AF7302, true, true, true)
            Citizen.InvokeNative(0x028F76B6E78246EB, npcs[v], horse[v], -1)
        end
        
        -- Target nearest player instead of just the spawning player
        if settings.aggroAllPlayersInRange then
            RetargetEntity(npcs[v], settings.retargetRange)
        else
            TaskCombatPed(npcs[v], PlayerPedId())
        end
    end
end

-- ============================================
-- ZOMBIE SPAWN FUNCTION (WITH RETARGETING)
-- ============================================
function spawnZombiesAtLocation(coords, count, timer)
    if not coords or count <= 0 then return end
    if not Config.EnableZombies then
        TriggerEvent('rNotify:NotifyLeft', "ZOMBIES", "Zombies are disabled in config", "generic_textures", "tick", 4000)
        return
    end
    
    local limits = getSpawnLimits()
    local settings = getRetargetSettings()
    
    -- Check total zombie limit
    local currentZombies = #adminSpawnedZombies
    local remaining = limits.totalZombies - currentZombies
    
    if remaining <= 0 then
        TriggerEvent('rNotify:NotifyLeft', "LIMIT REACHED", "Max " .. limits.totalZombies .. " zombies allowed. Delete some first.", "generic_textures", "tick", 4000)
        return
    end
    
    -- Adjust count if it would exceed total limit
    if count > remaining then
        TriggerEvent('rNotify:NotifyLeft', "ADJUSTED", "Spawning " .. remaining .. " zombies (limit: " .. limits.totalZombies .. ")", "generic_textures", "tick", 4000)
        count = remaining
    end
    
    if timer and timer > 0 then
        TriggerEvent('rNotify:NotifyLeft', "SPAWN SCHEDULED", count .. " zombies will spawn in " .. timer .. " seconds", "generic_textures", "tick", 4000)
        Citizen.CreateThread(function()
            Wait(timer * 1000)
            spawnZombiesAtLocation(coords, count, 0)
        end)
        return
    end
    
    -- Spawn in batches to prevent lag
    local batchSize = 10
    local spawned = 0
    
    Citizen.CreateThread(function()
        for i = 1, count do
            local spawnCoords = vector3(
                coords.x + math.random(-15, 15),
                coords.y + math.random(-15, 15),
                coords.z
            )
            
            local zombieData = Config.ZombieModels[math.random(1, #Config.ZombieModels)]
            local zombieModel = zombieData.model
            local zombieOutfit = zombieData.outfit
            
            RequestModel(zombieModel)
            local timeout = 0
            while not HasModelLoaded(zombieModel) and timeout < 100 do 
                Wait(10) 
                timeout = timeout + 1
            end
            
            if HasModelLoaded(zombieModel) then
                local zombie = CreatePed(zombieModel, spawnCoords.x, spawnCoords.y, spawnCoords.z, math.random(0, 360), true, true, true, true)
                adminSpawnedZombies[#adminSpawnedZombies + 1] = zombie
                
                Citizen.InvokeNative(0x283978A15512B2FE, zombie, true)
                
                if zombieOutfit > 0 then
                    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, zombie, zombieOutfit, false)
                end
                
                SetEntityHealth(zombie, Config.ZombieSettings.health or 100, 0)
                SetEntityMaxHealth(zombie, Config.ZombieSettings.health or 100)
                
                SetPedFleeAttributes(zombie, 0, false)
                SetPedCombatAttributes(zombie, 46, true)
                SetPedCombatAttributes(zombie, 5, true)
                SetPedCombatAttributes(zombie, 0, true)
                SetPedCombatAttributes(zombie, 2, true)
                SetPedCombatAttributes(zombie, 3, true)
                
                Citizen.InvokeNative(0xF166E48407BAC484, zombie, 0, 2)
                SetPedCombatRange(zombie, 0)
                SetPedCombatAbility(zombie, 100)
                
                SetPedConfigFlag(zombie, 100, true)
                SetPedConfigFlag(zombie, 281, true)
                
                if Config.ZombieSettings.canRun then
                    Citizen.InvokeNative(0x6535C12D41C0F6FC, zombie, 3.0)
                end
                
                trackedZombies[zombie] = {
                    isDead = false,
                    type = "admin"
                }
                
                local zombieBlip = Citizen.InvokeNative(0x554D9D53F696D002, 0x84AD0C5B, GetEntityCoords(zombie))
                Citizen.InvokeNative(0x9CB1A1623062F402, zombieBlip, "Zombie")
                Citizen.InvokeNative(0x662D364ABF16DE2F, zombieBlip, 0xFF0000FF)
                adminZombieBlips[#adminZombieBlips + 1] = zombieBlip
                
                -- Target nearest player instead of just the spawning player
                if settings.aggroAllPlayersInRange then
                    RetargetEntity(zombie, settings.retargetRange)
                else
                    TaskCombatPed(zombie, PlayerPedId())
                end
                
                -- Start AI thread for this zombie with retargeting
                local thisZombie = zombie
                Citizen.CreateThread(function()
                    while DoesEntityExist(thisZombie) and not IsPedDeadOrDying(thisZombie, true) do
                        Wait(2000)
                        
                        -- Check if current target is dead or out of range
                        local shouldRetarget = false
                        
                        if not IsPedInCombat(thisZombie, 0) then
                            shouldRetarget = true
                        else
                            -- Check if target is dead
                            local currentTarget = GetPedTaskCombatTarget(thisZombie, 0)
                            if currentTarget == 0 or not DoesEntityExist(currentTarget) or IsPedDeadOrDying(currentTarget, true) then
                                shouldRetarget = true
                            end
                        end
                        
                        if shouldRetarget then
                            RetargetEntity(thisZombie, settings.retargetRange)
                        end
                    end
                end)
                
                spawned = spawned + 1
            end
            
            -- Small delay between spawns to prevent lag
            if i % batchSize == 0 then
                Wait(100)
            else
                Wait(10)
            end
        end
        
        TriggerEvent('rNotify:NotifyLeft', "ZOMBIES", spawned .. " zombies have risen!", "generic_textures", "tick", 4000)
    end)
end

-- Zombie death tracking
Citizen.CreateThread(function()
    while true do
        Wait(500)
        for zombiePed, data in pairs(trackedZombies) do
            if DoesEntityExist(zombiePed) then
                if IsPedDeadOrDying(zombiePed, true) and not data.isDead then
                    trackedZombies[zombiePed].isDead = true
                    
                    local playerPed = PlayerPedId()
                    local killerPed = GetPedSourceOfDeath(zombiePed)
                    
                    if killerPed == playerPed or GetDistanceBetweenCoords(GetEntityCoords(playerPed), GetEntityCoords(zombiePed), true) < 50.0 then
                        TriggerServerEvent('rsg-bandits:server:rewardZombieKill')
                    end
                end
            else
                trackedZombies[zombiePed] = nil
            end
        end
    end
end)

-- Bandit death tracking and reward system
Citizen.CreateThread(function()
    while true do
        Wait(500)
        for banditPed, data in pairs(trackedBandits) do
            if DoesEntityExist(banditPed) then
                if IsPedDeadOrDying(banditPed, true) and not data.isDead then
                    trackedBandits[banditPed].isDead = true
                    
                    local playerPed = PlayerPedId()
                    local killerPed = GetPedSourceOfDeath(banditPed)
                    
                    if killerPed == playerPed or GetDistanceBetweenCoords(GetEntityCoords(playerPed), GetEntityCoords(banditPed), true) < 50.0 then
                        TriggerServerEvent('rsg-bandits:server:rewardPlayer')
                    end
                end
            else
                trackedBandits[banditPed] = nil
            end
        end
    end
end)

-- Main cleanup/despawn thread
Citizen.CreateThread(function()
    npcs = {}
    horse = {}
    banditBlips = {}
    while true do
        Wait(1000)
        if IsPedDeadOrDying(PlayerPedId(), true) and spawnbandits == true then
            TriggerEvent('rNotify:NotifyLeft', "LOOKS LIKE THEY GOT YOU", "DAMN", "generic_textures", "tick", 4000)
            Wait(5000)
            TriggerServerEvent('rsg-bandits:server:robplayer')
            TriggerEvent('rNotify:NotifyLeft', "AND YOU HAVE BEEN ROBBED", "FAIL", "generic_textures", "tick", 4000)
            
            -- Don't delete enemies if there are other players nearby
            local settings = getRetargetSettings()
            local myCoords = GetEntityCoords(PlayerPedId())
            local otherPlayers = GetPlayersInRange(myCoords, settings.retargetRange)
            
            -- Only cleanup if no other alive players are nearby
            if #otherPlayers <= 1 then -- 1 = just ourselves (dead)
                for v, k in pairs(npcs) do
                    if banditBlips[v] and DoesBlipExist(banditBlips[v]) then
                        RemoveBlip(banditBlips[v])
                    end
                    trackedBandits[k] = nil
                    DeleteEntity(k)
                end
                for v, k in pairs(horse) do
                    DeleteEntity(k)
                end
                calloffbandits = false
                spawnbandits = false
                banditBlips = {}
            else
                -- Retarget to remaining players
                Wait(settings.retargetDelay)
                RetargetAllEnemies()
                calloffbandits = false
                spawnbandits = false
            end
            break
        end
        if calloffbandits == true then
            -- Check if other players are still in range before cleaning up
            local settings = getRetargetSettings()
            local myCoords = GetEntityCoords(PlayerPedId())
            local otherPlayers = GetPlayersInRange(myCoords, settings.retargetRange)
            
            if #otherPlayers <= 1 then
                for v, k in pairs(npcs) do
                    if banditBlips[v] and DoesBlipExist(banditBlips[v]) then
                        RemoveBlip(banditBlips[v])
                    end
                    trackedBandits[k] = nil
                    DeleteEntity(k)
                end
                for v, k in pairs(horse) do
                    DeleteEntity(k)
                end
                calloffbandits = false
                spawnbandits = false
                banditBlips = {}
                TriggerEvent('rNotify:NotifyLeft', "BANDITS", "WATCH OUT", "generic_textures", "tick", 4000)
            else
                -- Don't cleanup - other players still engaging
                calloffbandits = false
                spawnbandits = false
            end
            break
        end
    end
end)

-- ============================================
-- DEAD BODY CLEANUP THREAD
-- ============================================
Citizen.CreateThread(function()
    local deadBodies = {} -- Track dead bodies with their death time
    
    while true do
        Wait(5000) -- Check every 5 seconds
        
        local cleanupEnabled = (Config.DeadBodyCleanup and Config.DeadBodyCleanup.enabled) ~= false
        local cleanupDelay = (Config.DeadBodyCleanup and Config.DeadBodyCleanup.delay) or 120
        local currentTime = GetGameTimer()
        
        if cleanupEnabled then
            -- Check admin spawned bandits
            for i, bandit in pairs(adminSpawnedBandits) do
                if DoesEntityExist(bandit) then
                    if IsPedDeadOrDying(bandit, true) then
                        if not deadBodies[bandit] then
                            deadBodies[bandit] = {
                                deathTime = currentTime,
                                type = 'bandit',
                                index = i
                            }
                        elseif (currentTime - deadBodies[bandit].deathTime) >= (cleanupDelay * 1000) then
                            -- Remove blip if exists
                            if adminBanditBlips[i] and DoesBlipExist(adminBanditBlips[i]) then
                                RemoveBlip(adminBanditBlips[i])
                                adminBanditBlips[i] = nil
                            end
                            DeleteEntity(bandit)
                            adminSpawnedBandits[i] = nil
                            trackedBandits[bandit] = nil
                            deadBodies[bandit] = nil
                        end
                    end
                else
                    adminSpawnedBandits[i] = nil
                    deadBodies[bandit] = nil
                end
            end
            
            -- Check config bandits (npcs table)
            for i, npc in pairs(npcs) do
                if DoesEntityExist(npc) then
                    if IsPedDeadOrDying(npc, true) then
                        if not deadBodies[npc] then
                            deadBodies[npc] = {
                                deathTime = currentTime,
                                type = 'config_bandit',
                                index = i
                            }
                        elseif (currentTime - deadBodies[npc].deathTime) >= (cleanupDelay * 1000) then
                            if banditBlips[i] and DoesBlipExist(banditBlips[i]) then
                                RemoveBlip(banditBlips[i])
                                banditBlips[i] = nil
                            end
                            DeleteEntity(npc)
                            npcs[i] = nil
                            trackedBandits[npc] = nil
                            deadBodies[npc] = nil
                        end
                    end
                else
                    npcs[i] = nil
                    deadBodies[npc] = nil
                end
            end
            
            -- Check horses
            for i, horseEntity in pairs(horse) do
                if DoesEntityExist(horseEntity) then
                    if IsPedDeadOrDying(horseEntity, true) then
                        if not deadBodies[horseEntity] then
                            deadBodies[horseEntity] = {
                                deathTime = currentTime,
                                type = 'horse',
                                index = i
                            }
                        elseif (currentTime - deadBodies[horseEntity].deathTime) >= (cleanupDelay * 1000) then
                            DeleteEntity(horseEntity)
                            horse[i] = nil
                            deadBodies[horseEntity] = nil
                        end
                    end
                else
                    horse[i] = nil
                    deadBodies[horseEntity] = nil
                end
            end
            
            -- Check admin spawned horses
            for i, horseEntity in pairs(adminSpawnedHorses) do
                if DoesEntityExist(horseEntity) then
                    if IsPedDeadOrDying(horseEntity, true) then
                        if not deadBodies[horseEntity] then
                            deadBodies[horseEntity] = {
                                deathTime = currentTime,
                                type = 'admin_horse',
                                index = i
                            }
                        elseif (currentTime - deadBodies[horseEntity].deathTime) >= (cleanupDelay * 1000) then
                            DeleteEntity(horseEntity)
                            adminSpawnedHorses[i] = nil
                            deadBodies[horseEntity] = nil
                        end
                    end
                else
                    adminSpawnedHorses[i] = nil
                    deadBodies[horseEntity] = nil
                end
            end
            
            -- Check zombies
            for i, zombie in pairs(adminSpawnedZombies) do
                if DoesEntityExist(zombie) then
                    if IsPedDeadOrDying(zombie, true) then
                        if not deadBodies[zombie] then
                            deadBodies[zombie] = {
                                deathTime = currentTime,
                                type = 'zombie',
                                index = i
                            }
                        elseif (currentTime - deadBodies[zombie].deathTime) >= (cleanupDelay * 1000) then
                            if adminZombieBlips[i] and DoesBlipExist(adminZombieBlips[i]) then
                                RemoveBlip(adminZombieBlips[i])
                                adminZombieBlips[i] = nil
                            end
                            DeleteEntity(zombie)
                            adminSpawnedZombies[i] = nil
                            trackedZombies[zombie] = nil
                            deadBodies[zombie] = nil
                        end
                    end
                else
                    adminSpawnedZombies[i] = nil
                    deadBodies[zombie] = nil
                end
            end
        end
    end
end)

-- ============================================
-- BANDIT SPAWN FUNCTION (WITH RETARGETING)
-- ============================================
function spawnBanditsAtLocation(coords, count, timer, mounted)
    if not coords or count <= 0 then return end
    
    if mounted == nil then mounted = true end
    
    local limits = getSpawnLimits()
    local settings = getRetargetSettings()
    
    -- Check total bandit limit
    local currentBandits = #adminSpawnedBandits
    local remaining = limits.totalBandits - currentBandits
    
    if remaining <= 0 then
        TriggerEvent('rNotify:NotifyLeft', "LIMIT REACHED", "Max " .. limits.totalBandits .. " bandits allowed. Delete some first.", "generic_textures", "tick", 4000)
        return
    end
    
    -- Adjust count if it would exceed total limit
    if count > remaining then
        TriggerEvent('rNotify:NotifyLeft', "ADJUSTED", "Spawning " .. remaining .. " bandits (limit: " .. limits.totalBandits .. ")", "generic_textures", "tick", 4000)
        count = remaining
    end
    
    if timer and timer > 0 then
        local typeText = mounted and "mounted " or "on-foot "
        TriggerEvent('rNotify:NotifyLeft', "SPAWN SCHEDULED", count .. " " .. typeText .. "bandits will spawn in " .. timer .. " seconds", "generic_textures", "tick", 4000)
        Citizen.CreateThread(function()
            Wait(timer * 1000)
            spawnBanditsAtLocation(coords, count, 0, mounted)
        end)
        return
    end
    
    -- Spawn in batches to prevent lag
    local batchSize = 5
    local spawned = 0
    
    Citizen.CreateThread(function()
        for i = 1, count do
            local spawnCoords = vector3(
                coords.x + math.random(-15, 15),
                coords.y + math.random(-15, 15),
                coords.z
            )
            
            local banditmodel = GetHashKey(Config.BanditsModel[math.random(1, #Config.BanditsModel)])
            local banditWeapon = Config.Weapons[math.random(1, #Config.Weapons)]
            
            RequestModel(banditmodel)
            local timeout = 0
            while not HasModelLoaded(banditmodel) and timeout < 100 do 
                Wait(10) 
                timeout = timeout + 1
            end
            
            if HasModelLoaded(banditmodel) then
                local bandit = CreatePed(banditmodel, spawnCoords, true, true, true, true)
                adminSpawnedBandits[#adminSpawnedBandits + 1] = bandit
                
                Citizen.InvokeNative(0x283978A15512B2FE, bandit, true)
                Citizen.InvokeNative(0x23f74c2fda6e7c61, 953018525, bandit)
                GiveWeaponToPed(bandit, banditWeapon, 50, true, true, 1, false, 0.5, 1.0, 1.0, true, 0, 0)
                SetCurrentPedWeapon(bandit, banditWeapon, true)
                
                -- Enhanced combat attributes for better targeting
                SetPedCombatAttributes(bandit, 46, true)
                SetPedCombatAttributes(bandit, 5, true)
                SetPedFleeAttributes(bandit, 0, false)
                
                trackedBandits[bandit] = {
                    isDead = false,
                    type = "admin"
                }
                
                local banditBlip = Citizen.InvokeNative(0x554D9D53F696D002, 0x84AD0C5B, GetEntityCoords(bandit))
                SetBlipSprite(banditBlip, 0x84AD0C5B)
                Citizen.InvokeNative(0x9CB1A1623062F402, banditBlip, mounted and "Mounted Bandit" or "Bandit on Foot")
                adminBanditBlips[#adminBanditBlips + 1] = banditBlip
                
                if mounted then
                    local horsemodel = GetHashKey(Config.HorseModels[math.random(1, #Config.HorseModels)])
                    
                    RequestModel(horsemodel)
                    local horseTimeout = 0
                    while not HasModelLoaded(horsemodel) and horseTimeout < 100 do 
                        Wait(10) 
                        horseTimeout = horseTimeout + 1
                    end
                    
                    if HasModelLoaded(horsemodel) then
                        local banditHorse = CreatePed(horsemodel, spawnCoords, true, true, true, true)
                        adminSpawnedHorses[#adminSpawnedHorses + 1] = banditHorse
                        
                        Citizen.InvokeNative(0x283978A15512B2FE, banditHorse, true)
                        Citizen.InvokeNative(0xD3A7B003ED343FD9, banditHorse, 0x20359E53, true, true, true)
                        Citizen.InvokeNative(0xD3A7B003ED343FD9, banditHorse, 0x508B80B9, true, true, true)
                        Citizen.InvokeNative(0xD3A7B003ED343FD9, banditHorse, 0xF0C30271, true, true, true)
                        Citizen.InvokeNative(0xD3A7B003ED343FD9, banditHorse, 0x12F0DF9F, true, true, true)
                        Citizen.InvokeNative(0xD3A7B003ED343FD9, banditHorse, 0x67AF7302, true, true, true)
                        Citizen.InvokeNative(0x028F76B6E78246EB, bandit, banditHorse, -1)
                    end
                end
                
                -- Target nearest player or all players in range
                if settings.aggroAllPlayersInRange then
                    RetargetEntity(bandit, settings.retargetRange)
                else
                    TaskCombatPed(bandit, PlayerPedId())
                end
                
                -- Start AI thread for this bandit with retargeting
                local thisBandit = bandit
                Citizen.CreateThread(function()
                    while DoesEntityExist(thisBandit) and not IsPedDeadOrDying(thisBandit, true) do
                        Wait(3000)
                        
                        -- Check if current target is dead or out of range
                        local shouldRetarget = false
                        
                        if not IsPedInCombat(thisBandit, 0) then
                            shouldRetarget = true
                        else
                            -- Check if target is dead
                            local currentTarget = GetPedTaskCombatTarget(thisBandit, 0)
                            if currentTarget == 0 or not DoesEntityExist(currentTarget) or IsPedDeadOrDying(currentTarget, true) then
                                shouldRetarget = true
                            end
                        end
                        
                        if shouldRetarget then
                            RetargetEntity(thisBandit, settings.retargetRange)
                        end
                    end
                end)
                
                spawned = spawned + 1
            end
            
            -- Small delay between spawns to prevent lag
            if i % batchSize == 0 then
                Wait(200)
            else
                Wait(50)
            end
        end
        
        local typeText = mounted and "MOUNTED BANDITS" or "BANDITS ON FOOT"
        TriggerEvent('rNotify:NotifyLeft', typeText, spawned .. " have seen you!", "generic_textures", "tick", 4000)
    end)
end

function deleteAllAdminBandits()
    local count = 0
    
    for _, blip in pairs(adminBanditBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    
    for _, bandit in pairs(adminSpawnedBandits) do
        if DoesEntityExist(bandit) then
            trackedBandits[bandit] = nil
            DeleteEntity(bandit)
            count = count + 1
        end
    end
    
    for _, horseEntity in pairs(adminSpawnedHorses) do
        if DoesEntityExist(horseEntity) then
            DeleteEntity(horseEntity)
        end
    end
    
    for _, location in ipairs(tempBanditLocations) do
        location.isTriggered = false
        location.lastTriggered = nil
        if location.blip and DoesBlipExist(location.blip) then
            RemoveBlip(location.blip)
            location.blip = nil
        end
    end
    
    adminSpawnedBandits = {}
    adminSpawnedHorses = {}
    adminBanditBlips = {}
    
    TriggerEvent('rNotify:NotifyLeft', "ADMIN DELETE", count .. " admin bandits deleted!", "generic_textures", "tick", 4000)
end

function deleteAllZombies()
    local count = 0
    
    for _, blip in pairs(adminZombieBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    
    for _, zombie in pairs(adminSpawnedZombies) do
        if DoesEntityExist(zombie) then
            trackedZombies[zombie] = nil
            DeleteEntity(zombie)
            count = count + 1
        end
    end
    
    adminSpawnedZombies = {}
    adminZombieBlips = {}
    
    TriggerEvent('rNotify:NotifyLeft', "ZOMBIES DELETED", count .. " zombies removed!", "generic_textures", "tick", 4000)
end

function deleteAllSpawned()
    deleteAllAdminBandits()
    deleteAllZombies()
end

-- Get current spawn counts for display
function getSpawnCounts()
    local bandits = 0
    local zombies = 0
    
    for _, bandit in pairs(adminSpawnedBandits) do
        if DoesEntityExist(bandit) and not IsPedDeadOrDying(bandit, true) then
            bandits = bandits + 1
        end
    end
    
    for _, zombie in pairs(adminSpawnedZombies) do
        if DoesEntityExist(zombie) and not IsPedDeadOrDying(zombie, true) then
            zombies = zombies + 1
        end
    end
    
    return bandits, zombies
end

function addLocationViaMenu()
    local limits = getSpawnLimits()
    local contextOptions = {}
    
    table.insert(contextOptions, {
        title = 'Add Location (Current Position)',
        description = 'Add location using your current position',
        icon = 'fas fa-map-marker-alt',
        onSelect = function()
            local input = lib.inputDialog('Add New Location', {
                {type = 'input', label = 'Location Name', placeholder = 'Enter a name for this location', required = true},
                {type = 'select', label = 'Spawn Type', options = {
                    {value = 'bandit', label = 'Bandits Only'},
                    {value = 'zombie', label = 'Zombies Only'},
                    {value = 'both', label = 'Bandits + Zombies'}
                }, default = 'bandit'},
                {type = 'select', label = 'Bandit Type', options = {
                    {value = 'mounted', label = 'Mounted'},
                    {value = 'foot', label = 'On Foot'},
                    {value = 'mixed', label = 'Mixed (50/50)'}
                }, default = 'mounted'},
                {type = 'number', label = 'Number of Bandits', default = 3, min = 0, max = limits.banditsPerSpawn},
                {type = 'number', label = 'Number of Zombies', default = 0, min = 0, max = limits.zombiesPerSpawn},
                {type = 'number', label = 'Spawn Delay (seconds)', description = 'Delay before spawn (0 for immediate)', default = 0, min = 0},
                {type = 'number', label = 'Proximity Radius (meters)', description = 'Radius to trigger spawn (0 for manual only)', default = 0, min = 0},
                {type = 'number', label = 'Initial Delay (seconds)', description = 'Delay before proximity trigger activates', default = 60, min = 0},
                {type = 'number', label = 'Cooldown (seconds)', description = 'Cooldown before proximity can trigger again', default = 300, min = 0},
                {type = 'checkbox', label = 'Enabled', description = 'Whether this location is active', checked = true}
            })
            
            if input and input[1] then
                local coords = GetEntityCoords(PlayerPedId())
                local heading = GetEntityHeading(PlayerPedId())
                
                TriggerServerEvent('rsg-bandits:server:saveLocation', {
                    coords = {x = coords.x, y = coords.y, z = coords.z},
                    heading = heading,
                    name = input[1],
                    spawnType = input[2] or 'bandit',
                    banditType = input[3] or 'mounted',
                    banditCount = input[4] or 3,
                    zombieCount = input[5] or 0,
                    timer = input[6] or 0,
                    proximity = input[7] or 0,
                    initialDelay = input[8] or 60,
                    cooldown = input[9] or 300,
                    enabled = input[10] ~= false
                })
            end
        end
    })
    
    table.insert(contextOptions, {
        title = 'Copy Current Coordinates',
        description = 'Copy your current coordinates for pasting',
        icon = 'fas fa-copy',
        onSelect = function()
            local coords = GetEntityCoords(PlayerPedId())
            local heading = GetEntityHeading(PlayerPedId())
            
            copiedCoords = {
                x = coords.x,
                y = coords.y,
                z = coords.z,
                heading = heading
            }
            
            TriggerEvent('rNotify:NotifyLeft', "COORDINATES COPIED", "Current position copied for pasting", "generic_textures", "tick", 4000)
        end
    })
    
    table.insert(contextOptions, {
        title = 'Add Location (Paste Coordinates)',
        description = copiedCoords and 'Paste previously copied coordinates' or 'No coordinates copied yet',
        icon = 'fas fa-paste',
        disabled = not copiedCoords,
        onSelect = function()
            if copiedCoords then
                local input = lib.inputDialog('Add New Location', {
                    {type = 'input', label = 'Location Name', placeholder = 'Enter a name for this location', required = true},
                    {type = 'number', label = 'X Coordinate', default = copiedCoords.x, required = true},
                    {type = 'number', label = 'Y Coordinate', default = copiedCoords.y, required = true},
                    {type = 'number', label = 'Z Coordinate', default = copiedCoords.z, required = true},
                    {type = 'number', label = 'Heading', default = copiedCoords.heading, required = true},
                    {type = 'select', label = 'Spawn Type', options = {
                        {value = 'bandit', label = 'Bandits Only'},
                        {value = 'zombie', label = 'Zombies Only'},
                        {value = 'both', label = 'Bandits + Zombies'}
                    }, default = 'bandit'},
                    {type = 'select', label = 'Bandit Type', options = {
                        {value = 'mounted', label = 'Mounted'},
                        {value = 'foot', label = 'On Foot'},
                        {value = 'mixed', label = 'Mixed (50/50)'}
                    }, default = 'mounted'},
                    {type = 'number', label = 'Number of Bandits', default = 3, min = 0, max = limits.banditsPerSpawn},
                    {type = 'number', label = 'Number of Zombies', default = 0, min = 0, max = limits.zombiesPerSpawn},
                    {type = 'number', label = 'Spawn Delay (seconds)', default = 0, min = 0},
                    {type = 'number', label = 'Proximity Radius (meters)', default = 0, min = 0},
                    {type = 'number', label = 'Initial Delay (seconds)', default = 60, min = 0},
                    {type = 'number', label = 'Cooldown (seconds)', default = 300, min = 0},
                    {type = 'checkbox', label = 'Enabled', checked = true}
                })
                
                if input and input[1] then
                    TriggerServerEvent('rsg-bandits:server:saveLocation', {
                        coords = {x = input[2], y = input[3], z = input[4]},
                        heading = input[5],
                        name = input[1],
                        spawnType = input[6] or 'bandit',
                        banditType = input[7] or 'mounted',
                        banditCount = input[8] or 3,
                        zombieCount = input[9] or 0,
                        timer = input[10] or 0,
                        proximity = input[11] or 0,
                        initialDelay = input[12] or 60,
                        cooldown = input[13] or 300,
                        enabled = input[14] ~= false
                    })
                end
            end
        end
    })
    
    table.insert(contextOptions, {
        title = 'Add Location (Manual Entry)',
        description = 'Enter coordinates manually',
        icon = 'fas fa-edit',
        onSelect = function()
            local coords = GetEntityCoords(PlayerPedId())
            local heading = GetEntityHeading(PlayerPedId())
            
            local input = lib.inputDialog('Add New Location', {
                {type = 'input', label = 'Location Name', placeholder = 'Enter a name for this location', required = true},
                {type = 'number', label = 'X Coordinate', placeholder = 'Current: ' .. string.format("%.2f", coords.x), required = true},
                {type = 'number', label = 'Y Coordinate', placeholder = 'Current: ' .. string.format("%.2f", coords.y), required = true},
                {type = 'number', label = 'Z Coordinate', placeholder = 'Current: ' .. string.format("%.2f", coords.z), required = true},
                {type = 'number', label = 'Heading', placeholder = 'Current: ' .. string.format("%.2f", heading), default = heading},
                {type = 'select', label = 'Spawn Type', options = {
                    {value = 'bandit', label = 'Bandits Only'},
                    {value = 'zombie', label = 'Zombies Only'},
                    {value = 'both', label = 'Bandits + Zombies'}
                }, default = 'bandit'},
                {type = 'select', label = 'Bandit Type', options = {
                    {value = 'mounted', label = 'Mounted'},
                    {value = 'foot', label = 'On Foot'},
                    {value = 'mixed', label = 'Mixed (50/50)'}
                }, default = 'mounted'},
                {type = 'number', label = 'Number of Bandits', default = 3, min = 0, max = limits.banditsPerSpawn},
                {type = 'number', label = 'Number of Zombies', default = 0, min = 0, max = limits.zombiesPerSpawn},
                {type = 'number', label = 'Spawn Delay (seconds)', default = 0, min = 0},
                {type = 'number', label = 'Proximity Radius (meters)', default = 0, min = 0},
                {type = 'number', label = 'Initial Delay (seconds)', default = 60, min = 0},
                {type = 'number', label = 'Cooldown (seconds)', default = 300, min = 0},
                {type = 'checkbox', label = 'Enabled', checked = true}
            })
            
            if input and input[1] and input[2] and input[3] and input[4] then
                TriggerServerEvent('rsg-bandits:server:saveLocation', {
                    coords = {x = input[2], y = input[3], z = input[4]},
                    heading = input[5] or heading,
                    name = input[1],
                    spawnType = input[6] or 'bandit',
                    banditType = input[7] or 'mounted',
                    banditCount = input[8] or 3,
                    zombieCount = input[9] or 0,
                    timer = input[10] or 0,
                    proximity = input[11] or 0,
                    initialDelay = input[12] or 60,
                    cooldown = input[13] or 300,
                    enabled = input[14] ~= false
                })
            end
        end
    })
    
    lib.registerContext({
        id = 'add_location_menu',
        title = 'Add New Location',
        menu = 'bandit_admin_menu',
        options = contextOptions
    })
    
    lib.showContext('add_location_menu')
end

function openBanditMenu()
    local limits = getSpawnLimits()
    local settings = getRetargetSettings()
    local currentBandits, currentZombies = getSpawnCounts()
    local contextOptions = {}
    
    -- Status display
    table.insert(contextOptions, {
        title = 'Current Status',
        description = 'Bandits: ' .. currentBandits .. '/' .. limits.totalBandits .. ' | Zombies: ' .. currentZombies .. '/' .. limits.totalZombies,
        icon = 'fas fa-info-circle',
        disabled = true
    })
    
    -- Retargeting status
    table.insert(contextOptions, {
        title = 'Retargeting: ' .. (settings.enabled and 'ON' or 'OFF'),
        description = 'Range: ' .. settings.retargetRange .. 'm | Aggro All: ' .. (settings.aggroAllPlayersInRange and 'Yes' or 'No'),
        icon = 'fas fa-crosshairs',
        disabled = true
    })
    
    -- ============================================
    -- BANDIT SECTION
    -- ============================================
    table.insert(contextOptions, {
        title = '--- BANDITS ---',
        description = 'Spawn and manage bandits (Max per spawn: ' .. limits.banditsPerSpawn .. ')',
        icon = 'fas fa-skull-crossbones',
        disabled = true
    })
    
    table.insert(contextOptions, {
        title = 'Spawn Mounted Bandits',
        description = 'Spawn bandits on horses at your location',
        icon = 'fas fa-horse',
        onSelect = function()
            local input = lib.inputDialog('Spawn Mounted Bandits', {
                {type = 'number', label = 'Number of Bandits (Max: ' .. limits.banditsPerSpawn .. ')', default = 3, min = 1, max = limits.banditsPerSpawn, required = true}
            })
            
            if input and input[1] then
                local coords = GetEntityCoords(PlayerPedId())
                spawnBanditsAtLocation(coords, input[1], 0, true)
            end
        end
    })
    
    table.insert(contextOptions, {
        title = 'Spawn Bandits on Foot',
        description = 'Spawn bandits without horses at your location',
        icon = 'fas fa-walking',
        onSelect = function()
            local input = lib.inputDialog('Spawn Bandits on Foot', {
                {type = 'number', label = 'Number of Bandits (Max: ' .. limits.banditsPerSpawn .. ')', default = 3, min = 1, max = limits.banditsPerSpawn, required = true}
            })
            
            if input and input[1] then
                local coords = GetEntityCoords(PlayerPedId())
                spawnBanditsAtLocation(coords, input[1], 0, false)
            end
        end
    })
    
    table.insert(contextOptions, {
        title = 'Spawn Mixed Bandits',
        description = 'Spawn a mix of mounted and on-foot bandits',
        icon = 'fas fa-dice',
        onSelect = function()
            local input = lib.inputDialog('Spawn Mixed Bandits', {
                {type = 'number', label = 'Total Number of Bandits (Max: ' .. limits.banditsPerSpawn .. ')', default = 6, min = 2, max = limits.banditsPerSpawn, required = true},
                {type = 'number', label = 'Percentage Mounted (0-100)', default = 50, min = 0, max = 100, required = true}
            })
            
            if input and input[1] then
                local coords = GetEntityCoords(PlayerPedId())
                local total = input[1]
                local percentMounted = input[2] / 100
                local mounted = math.floor(total * percentMounted)
                local onFoot = total - mounted
                
                if mounted > 0 then
                    spawnBanditsAtLocation(coords, mounted, 0, true)
                end
                
                if onFoot > 0 then
                    spawnBanditsAtLocation(coords, onFoot, 0, false)
                end
            end
        end
    })
    
    table.insert(contextOptions, {
        title = 'Delete All Bandits (' .. currentBandits .. ')',
        description = 'Remove all admin spawned bandits and horses',
        icon = 'fas fa-trash',
        onSelect = function()
            deleteAllAdminBandits()
        end
    })
    
    -- ============================================
    -- ZOMBIE SECTION
    -- ============================================
    table.insert(contextOptions, {
        title = '--- ZOMBIES ---',
        description = 'Spawn and manage zombies (Max per spawn: ' .. limits.zombiesPerSpawn .. ')',
        icon = 'fas fa-biohazard',
        disabled = true
    })
    
    table.insert(contextOptions, {
        title = 'Spawn Zombies',
        description = 'Spawn zombies at your location',
        icon = 'fas fa-biohazard',
        onSelect = function()
            local input = lib.inputDialog('Spawn Zombies', {
                {type = 'number', label = 'Number of Zombies (Max: ' .. limits.zombiesPerSpawn .. ')', default = 5, min = 1, max = limits.zombiesPerSpawn, required = true}
            })
            
            if input and input[1] then
                local coords = GetEntityCoords(PlayerPedId())
                spawnZombiesAtLocation(coords, input[1], 0)
            end
        end
    })
    
    table.insert(contextOptions, {
        title = 'Spawn Zombie Horde',
        description = 'Spawn a large horde of zombies (Max: ' .. limits.hordeSize .. ')',
        icon = 'fas fa-skull',
        onSelect = function()
            local input = lib.inputDialog('Spawn Zombie Horde', {
                {type = 'number', label = 'Horde Size (Max: ' .. limits.hordeSize .. ')', default = 20, min = 5, max = limits.hordeSize, required = true},
                {type = 'number', label = 'Spawn Delay (seconds)', default = 0, min = 0, max = 60}
            })
            
            if input and input[1] then
                local coords = GetEntityCoords(PlayerPedId())
                spawnZombiesAtLocation(coords, input[1], input[2] or 0)
            end
        end
    })
    
    table.insert(contextOptions, {
        title = 'Delete All Zombies (' .. currentZombies .. ')',
        description = 'Remove all spawned zombies',
        icon = 'fas fa-trash-alt',
        onSelect = function()
            deleteAllZombies()
        end
    })
    
    -- ============================================
    -- MIXED SPAWN SECTION
    -- ============================================
    table.insert(contextOptions, {
        title = '--- MIXED SPAWNS ---',
        description = 'Spawn both bandits and zombies',
        icon = 'fas fa-users',
        disabled = true
    })
    
    table.insert(contextOptions, {
        title = 'Spawn Bandits + Zombies',
        description = 'Spawn both at your location',
        icon = 'fas fa-users-slash',
        onSelect = function()
            local input = lib.inputDialog('Spawn Mixed Enemies', {
                {type = 'number', label = 'Number of Bandits (Max: ' .. limits.banditsPerSpawn .. ')', default = 3, min = 0, max = limits.banditsPerSpawn, required = true},
                {type = 'select', label = 'Bandit Type', options = {
                    {value = 'mounted', label = 'Mounted'},
                    {value = 'foot', label = 'On Foot'},
                    {value = 'mixed', label = 'Mixed'}
                }, default = 'mounted'},
                {type = 'number', label = 'Number of Zombies (Max: ' .. limits.zombiesPerSpawn .. ')', default = 5, min = 0, max = limits.zombiesPerSpawn, required = true}
            })
            
            if input then
                local coords = GetEntityCoords(PlayerPedId())
                
                if input[1] and input[1] > 0 then
                    if input[2] == 'mixed' then
                        local mounted = math.floor(input[1] / 2)
                        local onFoot = input[1] - mounted
                        spawnBanditsAtLocation(coords, mounted, 0, true)
                        spawnBanditsAtLocation(coords, onFoot, 0, false)
                    else
                        spawnBanditsAtLocation(coords, input[1], 0, input[2] == 'mounted')
                    end
                end
                
                if input[3] and input[3] > 0 then
                    spawnZombiesAtLocation(coords, input[3], 0)
                end
            end
        end
    })
    
    table.insert(contextOptions, {
        title = 'Delete All Spawned (' .. (currentBandits + currentZombies) .. ')',
        description = 'Remove all bandits AND zombies',
        icon = 'fas fa-broom',
        onSelect = function()
            deleteAllSpawned()
        end
    })
    
    -- ============================================
    -- RETARGETING CONTROLS
    -- ============================================
    table.insert(contextOptions, {
        title = '--- TARGETING ---',
        description = 'Force retarget all enemies',
        icon = 'fas fa-crosshairs',
        disabled = true
    })
    
    table.insert(contextOptions, {
        title = 'Force Retarget All Enemies',
        description = 'Make all enemies target nearest players',
        icon = 'fas fa-bullseye',
        onSelect = function()
            local count = RetargetAllEnemies()
            TriggerEvent('rNotify:NotifyLeft', "RETARGET", count .. " enemies retargeted to nearest players", "generic_textures", "tick", 4000)
        end
    })
    
    -- ============================================
    -- LOCATION MANAGEMENT
    -- ============================================
    table.insert(contextOptions, {
        title = '--- LOCATIONS ---',
        description = 'Manage spawn locations',
        icon = 'fas fa-map',
        disabled = true
    })
    
    table.insert(contextOptions, {
        title = 'Add New Location',
        description = 'Add a new spawn location (saved to server)',
        icon = 'fas fa-plus-circle',
        onSelect = function()
            addLocationViaMenu()
        end
    })
    
    if #tempBanditLocations > 0 then
        table.insert(contextOptions, {
            title = 'Manage Saved Locations',
            description = 'View and manage ' .. #tempBanditLocations .. ' saved locations',
            icon = 'fas fa-map-marked-alt',
            onSelect = function()
                openSavedLocationsMenu()
            end
        })
    end
    
    lib.registerContext({
        id = 'bandit_admin_menu',
        title = 'Enemy Spawn Menu',
        options = contextOptions
    })
    
    lib.showContext('bandit_admin_menu')
end

function openSavedLocationsMenu()
    local contextOptions = {}
    
    for i, location in ipairs(tempBanditLocations) do
        local statusIcon = location.enabled and '[ON]' or '[OFF]'
        local typeIcon = ''
        
        if location.spawnType == 'zombie' then
            typeIcon = '[Z]'
        elseif location.spawnType == 'both' then
            typeIcon = '[B+Z]'
        else
            if location.banditType == 'mounted' then
                typeIcon = '[M]'
            elseif location.banditType == 'foot' then
                typeIcon = '[F]'
            else
                typeIcon = '[X]'
            end
        end
        
        local countText = ''
        if location.spawnType == 'zombie' then
            countText = 'Zombies: ' .. (location.zombieCount or 0)
        elseif location.spawnType == 'both' then
            countText = 'B: ' .. (location.banditCount or 0) .. ' | Z: ' .. (location.zombieCount or 0)
        else
            countText = 'Bandits: ' .. (location.banditCount or 0)
        end
        
        table.insert(contextOptions, {
            title = statusIcon .. ' ' .. typeIcon .. ' ' .. location.name,
            description = countText .. ' | Proximity: ' .. location.proximity .. 'm | By: ' .. (location.createdBy or 'Unknown'),
            icon = 'fas fa-map-marker',
            onSelect = function()
                openLocationActionsMenu(i, location)
            end
        })
    end
    
    lib.registerContext({
        id = 'saved_locations_menu',
        title = 'Saved Locations (' .. #tempBanditLocations .. ')',
        menu = 'bandit_admin_menu',
        options = contextOptions
    })
    
    lib.showContext('saved_locations_menu')
end

function openLocationActionsMenu(index, location)
    local limits = getSpawnLimits()
    local contextOptions = {}
    
    local typeText = location.spawnType == 'zombie' and 'Zombies' or location.spawnType == 'both' and 'Mixed' or 'Bandits'
    
    table.insert(contextOptions, {
        title = 'Spawn Here Now',
        description = 'Type: ' .. typeText .. (location.timer > 0 and ' | Timer: ' .. location.timer .. 's' or ''),
        icon = 'fas fa-user-ninja',
        onSelect = function()
            local input = lib.inputDialog('Spawn at ' .. location.name, {
                {type = 'number', label = 'Number of Bandits', default = location.banditCount or 3, min = 0, max = limits.banditsPerSpawn},
                {type = 'number', label = 'Number of Zombies', default = location.zombieCount or 0, min = 0, max = limits.zombiesPerSpawn},
                {type = 'select', label = 'Bandit Type', options = {
                    {value = 'default', label = 'Use Saved (' .. (location.banditType or 'mounted') .. ')'},
                    {value = 'mounted', label = 'Force Mounted'},
                    {value = 'foot', label = 'Force On Foot'},
                    {value = 'mixed', label = 'Force Mixed'}
                }, default = 'default'}
            })
            
            if input then
                local banditCount = input[1] or 0
                local zombieCount = input[2] or 0
                local banditType = input[3] == 'default' and (location.banditType or 'mounted') or input[3]
                
                if banditCount > 0 then
                    if banditType == 'mixed' then
                        local mounted = math.floor(banditCount / 2)
                        local onFoot = banditCount - mounted
                        spawnBanditsAtLocation(location.coords, mounted, location.timer, true)
                        spawnBanditsAtLocation(location.coords, onFoot, location.timer, false)
                    else
                        local isMounted = banditType == 'mounted'
                        spawnBanditsAtLocation(location.coords, banditCount, location.timer, isMounted)
                    end
                end
                
                if zombieCount > 0 then
                    spawnZombiesAtLocation(location.coords, zombieCount, location.timer)
                end
            end
        end
    })
    
    table.insert(contextOptions, {
        title = 'Teleport to Location',
        description = 'Teleport to this saved location',
        icon = 'fas fa-location-arrow',
        onSelect = function()
            SetEntityCoords(PlayerPedId(), location.coords.x, location.coords.y, location.coords.z, false, false, false, true)
            SetEntityHeading(PlayerPedId(), location.heading)
            TriggerEvent('rNotify:NotifyLeft', "TELEPORTED", "Teleported to " .. location.name, "generic_textures", "tick", 4000)
        end
    })
    
    table.insert(contextOptions, {
        title = location.enabled and 'Disable Location' or 'Enable Location',
        description = location.enabled and 'Disable proximity trigger' or 'Enable proximity trigger',
        icon = location.enabled and 'fas fa-toggle-on' or 'fas fa-toggle-off',
        onSelect = function()
            location.enabled = not location.enabled
            TriggerServerEvent('rsg-bandits:server:updateLocation', {
                id = location.id,
                coords = {x = location.coords.x, y = location.coords.y, z = location.coords.z},
                heading = location.heading,
                name = location.name,
                spawnType = location.spawnType,
                banditType = location.banditType,
                banditCount = location.banditCount,
                zombieCount = location.zombieCount,
                timer = location.timer,
                proximity = location.proximity,
                initialDelay = location.initialDelay,
                cooldown = location.cooldown,
                enabled = location.enabled,
                createdBy = location.createdBy
            })
            TriggerEvent('rNotify:NotifyLeft', "LOCATION UPDATED", location.name .. " " .. (location.enabled and "enabled" or "disabled"), "generic_textures", "tick", 4000)
        end
    })
    
    table.insert(contextOptions, {
        title = 'Delete Location',
        description = 'Remove this saved location from server',
        icon = 'fas fa-trash',
        onSelect = function()
            local confirm = lib.alertDialog({
                header = 'Delete Location',
                content = 'Are you sure you want to delete "' .. location.name .. '"? This will remove it from the server.',
                centered = true,
                cancel = true
            })
            
            if confirm == 'confirm' then
                TriggerServerEvent('rsg-bandits:server:deleteLocation', location.id)
            end
        end
    })
    
    lib.registerContext({
        id = 'location_actions_menu',
        title = location.name,
        menu = 'saved_locations_menu',
        options = contextOptions
    })
    
    lib.showContext('location_actions_menu')
end

-- Proximity trigger system for saved locations
Citizen.CreateThread(function()
    while true do
        Wait(1000)
        local playerCoords = GetEntityCoords(PlayerPedId())
        
        for _, location in ipairs(tempBanditLocations) do
            if location.enabled and location.proximity > 0 then
                local dis = GetDistanceBetweenCoords(playerCoords.x, playerCoords.y, playerCoords.z, location.coords.x, location.coords.y, location.coords.z)
                
                if dis < location.proximity then
                    if not pendingProximityRequests[location.id] then
                        pendingProximityRequests[location.id] = true
                        TriggerServerEvent('rsg-bandits:server:requestProximityTrigger', location.id)
                    end
                elseif dis >= location.proximity * 1.5 then
                    pendingProximityRequests[location.id] = nil
                    TriggerServerEvent('rsg-bandits:server:playerLeftProximity', location.id)
                end
            end
        end
    end
end)

-- Server approved proximity spawn (updated for zombies)
RegisterNetEvent('rsg-bandits:client:triggerProximityBandits', function(locationId, locationData)
    pendingProximityRequests[locationId] = nil
    
    local location = nil
    for _, loc in ipairs(tempBanditLocations) do
        if loc.id == locationId then
            location = loc
            break
        end
    end
    
    if not location and locationData then
        location = {
            coords = vector3(locationData.coords.x, locationData.coords.y, locationData.coords.z),
            spawnType = locationData.spawnType or 'bandit',
            banditType = locationData.banditType or 'mounted',
            banditCount = locationData.banditCount or 3,
            zombieCount = locationData.zombieCount or 0,
            timer = locationData.timer or 0
        }
    end
    
    if location then
        -- Spawn based on type
        if location.spawnType == 'zombie' then
            if location.zombieCount > 0 then
                spawnZombiesAtLocation(location.coords, location.zombieCount, location.timer)
            end
        elseif location.spawnType == 'both' then
            -- Spawn both bandits and zombies
            if location.banditCount > 0 then
                if location.banditType == 'mixed' then
                    local mounted = math.floor(location.banditCount / 2)
                    local onFoot = location.banditCount - mounted
                    spawnBanditsAtLocation(location.coords, mounted, location.timer, true)
                    spawnBanditsAtLocation(location.coords, onFoot, location.timer, false)
                else
                    local isMounted = location.banditType == 'mounted'
                    spawnBanditsAtLocation(location.coords, location.banditCount, location.timer, isMounted)
                end
            end
            if location.zombieCount > 0 then
                spawnZombiesAtLocation(location.coords, location.zombieCount, location.timer)
            end
        else
            -- Default: bandits only
            if location.banditCount > 0 then
                if location.banditType == 'mixed' then
                    local mounted = math.floor(location.banditCount / 2)
                    local onFoot = location.banditCount - mounted
                    spawnBanditsAtLocation(location.coords, mounted, location.timer, true)
                    spawnBanditsAtLocation(location.coords, onFoot, location.timer, false)
                else
                    local isMounted = location.banditType == 'mounted'
                    spawnBanditsAtLocation(location.coords, location.banditCount, location.timer, isMounted)
                end
            end
        end
    end
end)

RegisterNetEvent('rsg-bandits:client:proximityTriggerDenied', function(locationId, reason)
    pendingProximityRequests[locationId] = nil
end)

-- Register commands
RegisterCommand('banditmenu', function()
    openBanditMenu()
end, false)

RegisterCommand('spawnbandits', function(source, args)
    local limits = getSpawnLimits()
    local count = tonumber(args[1]) or 3
    local banditType = args[2] or 'mounted'
    
    if count > limits.banditsPerSpawn then count = limits.banditsPerSpawn end
    if count < 1 then count = 1 end
    
    local coords = GetEntityCoords(PlayerPedId())
    
    if banditType == 'foot' then
        spawnBanditsAtLocation(coords, count, 0, false)
    elseif banditType == 'mixed' then
        local mounted = math.floor(count / 2)
        local onFoot = count - mounted
        spawnBanditsAtLocation(coords, mounted, 0, true)
        spawnBanditsAtLocation(coords, onFoot, 0, false)
    else
        spawnBanditsAtLocation(coords, count, 0, true)
    end
end, false)

RegisterCommand('spawnzombies', function(source, args)
    local limits = getSpawnLimits()
    local count = tonumber(args[1]) or 5
    
    if count > limits.zombiesPerSpawn then count = limits.zombiesPerSpawn end
    if count < 1 then count = 1 end
    
    local coords = GetEntityCoords(PlayerPedId())
    spawnZombiesAtLocation(coords, count, 0)
end, false)

RegisterCommand('deletebandits', function()
    deleteAllAdminBandits()
end, false)

RegisterCommand('deletezombies', function()
    deleteAllZombies()
end, false)

RegisterCommand('deleteall', function()
    deleteAllSpawned()
end, false)

RegisterCommand('addlocation', function()
    addLocationViaMenu()
end, false)

-- Command to force retarget all enemies
RegisterCommand('retarget', function()
    local count = RetargetAllEnemies()
    TriggerEvent('rNotify:NotifyLeft', "RETARGET", count .. " enemies retargeted", "generic_textures", "tick", 4000)
end, false)

-- Command to show current spawn counts
RegisterCommand('spawncount', function()
    local bandits, zombies = getSpawnCounts()
    local limits = getSpawnLimits()
    TriggerEvent('rNotify:NotifyLeft', "SPAWN COUNT", "Bandits: " .. bandits .. "/" .. limits.totalBandits .. " | Zombies: " .. zombies .. "/" .. limits.totalZombies, "generic_textures", "tick", 4000)
end, false)

-- Cooldown timer function
function cooldownTimer()
    cooldownSecondsRemaining = Config.Cooldown
    Citizen.CreateThread(function()
        while cooldownSecondsRemaining > 0 do
            Wait(1000)
            cooldownSecondsRemaining = cooldownSecondsRemaining - 1
            print(cooldownSecondsRemaining)
        end
    end)
end

-- Resource stop cleanup
AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    for v, k in pairs(npcs) do
        if DoesEntityExist(k) then
            DeleteEntity(k)
        end
    end
    for v, k in pairs(horse) do
        if DoesEntityExist(k) then
            DeleteEntity(k)
        end
    end
    
    for v, k in pairs(banditBlips) do
        if DoesBlipExist(k) then
            RemoveBlip(k)
        end
    end
    
    for _, bandit in pairs(adminSpawnedBandits) do
        if DoesEntityExist(bandit) then
            DeleteEntity(bandit)
        end
    end
    for _, horseEntity in pairs(adminSpawnedHorses) do
        if DoesEntityExist(horseEntity) then
            DeleteEntity(horseEntity)
        end
    end
    
    for _, blip in pairs(adminBanditBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    
    -- Cleanup zombies
    for _, zombie in pairs(adminSpawnedZombies) do
        if DoesEntityExist(zombie) then
            DeleteEntity(zombie)
        end
    end
    
    for _, blip in pairs(adminZombieBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    
    for _, location in ipairs(tempBanditLocations) do
        if location.blip and DoesBlipExist(location.blip) then
            RemoveBlip(location.blip)
        end
    end
    
    trackedBandits = {}
    trackedZombies = {}
end)