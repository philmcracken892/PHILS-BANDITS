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
            banditType = loc.banditType or 'mounted',
            banditCount = loc.banditCount or 3,
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
                -- Check if this specific location is enabled
                if k.enabled ~= false then
                    local coords = GetEntityCoords(PlayerPedId())
                    local dis = GetDistanceBetweenCoords(coords.x, coords.y, coords.z, k.triggerPoint.x, k.triggerPoint.y, k.triggerPoint.z)
                    if dis < Config.TriggerBandits and spawnbandits == false then
                        banditsTrigger(k.bandits, k.mounted)
                    end
                    if dis >= Config.CalloffBandits and spawnbandits == true then
                        calloffbandits = true
                    end
                end
            end
        end
    end
end)

function banditsTrigger(bandits, mounted)
    spawnbandits = true
    -- Default to mounted if not specified
    if mounted == nil then mounted = true end
    
    for v, k in pairs(bandits) do
        local banditmodel = GetHashKey(Config.BanditsModel[math.random(1, #Config.BanditsModel)])
        local banditWeapon = Config.Weapons[math.random(1, #Config.Weapons)]
        
        RequestModel(banditmodel)
        if not HasModelLoaded(banditmodel) then RequestModel(banditmodel) end
        while not HasModelLoaded(banditmodel) do Wait(1) end
        Citizen.Wait(100)
        
        -- Create bandits
        npcs[v] = CreatePed(banditmodel, k, true, true, true, true)
        Citizen.InvokeNative(0x283978A15512B2FE, npcs[v], true)
        Citizen.InvokeNative(0x23f74c2fda6e7c61, 953018525, npcs[v])
        
        -- Give weapon to bandits
        GiveWeaponToPed(npcs[v], banditWeapon, 50, true, true, 1, false, 0.5, 1.0, 1.0, true, 0, 0)
        SetCurrentPedWeapon(npcs[v], banditWeapon, true)
        
        -- Track bandit for death detection
        trackedBandits[npcs[v]] = {
            isDead = false,
            type = "config"
        }
        
        -- Create blip for bandit
        local banditCoords = GetEntityCoords(npcs[v])
        local banditBlip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, banditCoords.x, banditCoords.y, banditCoords.z)
        Citizen.InvokeNative(0x9CB1A1623062F402, banditBlip, mounted and "Mounted Bandit" or "Bandit")
        Citizen.InvokeNative(0x662D364ABF16DE2F, banditBlip, 0x59FA676C)
        banditBlips[v] = banditBlip
        
        -- Only spawn horse if mounted is true
        if mounted then
            local horsemodel = GetHashKey(Config.HorseModels[math.random(1, #Config.HorseModels)])
            
            RequestModel(horsemodel)
            if not HasModelLoaded(horsemodel) then RequestModel(horsemodel) end
            while not HasModelLoaded(horsemodel) do Wait(1) end
            Citizen.Wait(100)
            
            horse[v] = CreatePed(horsemodel, k, true, true, true, true)
            Citizen.InvokeNative(0x283978A15512B2FE, horse[v], true)
            Citizen.InvokeNative(0xD3A7B003ED343FD9, horse[v], 0x20359E53, true, true, true) -- saddle
            Citizen.InvokeNative(0xD3A7B003ED343FD9, horse[v], 0x508B80B9, true, true, true) -- blanket
            Citizen.InvokeNative(0xD3A7B003ED343FD9, horse[v], 0xF0C30271, true, true, true) -- bag
            Citizen.InvokeNative(0xD3A7B003ED343FD9, horse[v], 0x12F0DF9F, true, true, true) -- bedroll
            Citizen.InvokeNative(0xD3A7B003ED343FD9, horse[v], 0x67AF7302, true, true, true) -- stirups
            Citizen.InvokeNative(0x028F76B6E78246EB, npcs[v], horse[v], -1)
        end
        
        TaskCombatPed(npcs[v], PlayerPedId())
    end
end

-- Bandit death tracking and reward system
Citizen.CreateThread(function()
    while true do
        Wait(500)
        for banditPed, data in pairs(trackedBandits) do
            if DoesEntityExist(banditPed) then
                if IsPedDeadOrDying(banditPed, true) and not data.isDead then
                    trackedBandits[banditPed].isDead = true
                    
                    -- Check if player killed the bandit
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
            break
        end
        if calloffbandits == true then
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
            break
        end
    end
end)

-- Modified spawn function with timer and mount support
function spawnBanditsAtLocation(coords, count, timer, mounted)
    if not coords or count <= 0 then return end
    
    -- Default to mounted if not specified
    if mounted == nil then mounted = true end
    
    if timer and timer > 0 then
        local typeText = mounted and "mounted " or "on-foot "
        TriggerEvent('rNotify:NotifyLeft', "SPAWN SCHEDULED", count .. " " .. typeText .. "bandits will spawn in " .. timer .. " seconds", "generic_textures", "tick", 4000)
        Citizen.CreateThread(function()
            Wait(timer * 1000)
            spawnBanditsAtLocation(coords, count, 0, mounted)
        end)
        return
    end
    
    for i = 1, count do
        local spawnCoords = vector3(
            coords.x + math.random(-10, 10),
            coords.y + math.random(-10, 10),
            coords.z
        )
        
        local banditmodel = GetHashKey(Config.BanditsModel[math.random(1, #Config.BanditsModel)])
        local banditWeapon = Config.Weapons[math.random(1, #Config.Weapons)]
        
        RequestModel(banditmodel)
        if not HasModelLoaded(banditmodel) then RequestModel(banditmodel) end
        while not HasModelLoaded(banditmodel) do Wait(1) end
        Citizen.Wait(100)
        
        local bandit = CreatePed(banditmodel, spawnCoords, true, true, true, true)
        adminSpawnedBandits[#adminSpawnedBandits + 1] = bandit
        
        Citizen.InvokeNative(0x283978A15512B2FE, bandit, true)
        Citizen.InvokeNative(0x23f74c2fda6e7c61, 953018525, bandit)
        GiveWeaponToPed(bandit, banditWeapon, 50, true, true, 1, false, 0.5, 1.0, 1.0, true, 0, 0)
        SetCurrentPedWeapon(bandit, banditWeapon, true)
        
        -- Track bandit for death detection
        trackedBandits[bandit] = {
            isDead = false,
            type = "admin"
        }
        
        -- Create blip for admin spawned bandit
        local banditBlip = Citizen.InvokeNative(0x554D9D53F696D002, 0x84AD0C5B, GetEntityCoords(bandit))
        SetBlipSprite(banditBlip, 0x84AD0C5B)
        Citizen.InvokeNative(0x9CB1A1623062F402, banditBlip, mounted and "Mounted Bandit" or "Bandit on Foot")
        adminBanditBlips[#adminBanditBlips + 1] = banditBlip
        
        -- Only spawn horse if mounted is true
        if mounted then
            local horsemodel = GetHashKey(Config.HorseModels[math.random(1, #Config.HorseModels)])
            
            RequestModel(horsemodel)
            if not HasModelLoaded(horsemodel) then RequestModel(horsemodel) end
            while not HasModelLoaded(horsemodel) do Wait(1) end
            Citizen.Wait(100)
            
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
        
        TaskCombatPed(bandit, PlayerPedId())
    end
    
    local typeText = mounted and "MOUNTED BANDITS" or "BANDITS ON FOOT"
    TriggerEvent('rNotify:NotifyLeft', typeText, count .. " have seen you!", "generic_textures", "tick", 4000)
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

function addLocationViaMenu()
    local contextOptions = {}
    
    table.insert(contextOptions, {
        title = 'Add Location (Current Position)',
        description = 'Add location using your current position',
        icon = 'fas fa-map-marker-alt',
        onSelect = function()
            local input = lib.inputDialog('Add New Location', {
                {type = 'input', label = 'Location Name', placeholder = 'Enter a name for this location', required = true},
                {type = 'select', label = 'Bandit Type', options = {
                    {value = 'mounted', label = '?? Mounted'},
                    {value = 'foot', label = '?? On Foot'},
                    {value = 'mixed', label = '?? Mixed (50/50)'}
                }, default = 'mounted'},
                {type = 'number', label = 'Number of Bandits', default = 3, min = 1, max = 10},
                {type = 'number', label = 'Spawn Delay (seconds)', description = 'Delay before bandits spawn (0 for immediate)', default = 0, min = 0},
                {type = 'number', label = 'Proximity Radius (meters)', description = 'Radius to trigger spawn (0 for manual only)', default = 0, min = 0},
                {type = 'number', label = 'Initial Delay (seconds)', description = 'Delay before proximity trigger activates (0 for immediate)', default = 60, min = 0},
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
                    banditType = input[2] or 'mounted',
                    banditCount = input[3] or 3,
                    timer = input[4] or 0,
                    proximity = input[5] or 0,
                    initialDelay = input[6] or 60,
                    cooldown = input[7] or 300,
                    enabled = input[8] ~= false
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
                    {type = 'select', label = 'Bandit Type', options = {
                        {value = 'mounted', label = '?? Mounted'},
                        {value = 'foot', label = '?? On Foot'},
                        {value = 'mixed', label = '?? Mixed (50/50)'}
                    }, default = 'mounted'},
                    {type = 'number', label = 'Number of Bandits', default = 3, min = 1, max = 10},
                    {type = 'number', label = 'Spawn Delay (seconds)', description = 'Delay before bandits spawn (0 for immediate)', default = 0, min = 0},
                    {type = 'number', label = 'Proximity Radius (meters)', description = 'Radius to trigger spawn (0 for manual only)', default = 0, min = 0},
                    {type = 'number', label = 'Initial Delay (seconds)', description = 'Delay before proximity trigger activates (0 for immediate)', default = 60, min = 0},
                    {type = 'number', label = 'Cooldown (seconds)', description = 'Cooldown before proximity can trigger again', default = 300, min = 0},
                    {type = 'checkbox', label = 'Enabled', description = 'Whether this location is active', checked = true}
                })
                
                if input and input[1] then
                    TriggerServerEvent('rsg-bandits:server:saveLocation', {
                        coords = {x = input[2], y = input[3], z = input[4]},
                        heading = input[5],
                        name = input[1],
                        banditType = input[6] or 'mounted',
                        banditCount = input[7] or 3,
                        timer = input[8] or 0,
                        proximity = input[9] or 0,
                        initialDelay = input[10] or 60,
                        cooldown = input[11] or 300,
                        enabled = input[12] ~= false
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
                {type = 'select', label = 'Bandit Type', options = {
                    {value = 'mounted', label = '?? Mounted'},
                    {value = 'foot', label = '?? On Foot'},
                    {value = 'mixed', label = '?? Mixed (50/50)'}
                }, default = 'mounted'},
                {type = 'number', label = 'Number of Bandits', default = 3, min = 1, max = 10},
                {type = 'number', label = 'Spawn Delay (seconds)', description = 'Delay before bandits spawn (0 for immediate)', default = 0, min = 0},
                {type = 'number', label = 'Proximity Radius (meters)', description = 'Radius to trigger spawn (0 for manual only)', default = 0, min = 0},
                {type = 'number', label = 'Initial Delay (seconds)', description = 'Delay before proximity trigger activates (0 for immediate)', default = 60, min = 0},
                {type = 'number', label = 'Cooldown (seconds)', description = 'Cooldown before proximity can trigger again', default = 300, min = 0},
                {type = 'checkbox', label = 'Enabled', description = 'Whether this location is active', checked = true}
            })
            
            if input and input[1] and input[2] and input[3] and input[4] then
                TriggerServerEvent('rsg-bandits:server:saveLocation', {
                    coords = {x = input[2], y = input[3], z = input[4]},
                    heading = input[5] or heading,
                    name = input[1],
                    banditType = input[6] or 'mounted',
                    banditCount = input[7] or 3,
                    timer = input[8] or 0,
                    proximity = input[9] or 0,
                    initialDelay = input[10] or 60,
                    cooldown = input[11] or 300,
                    enabled = input[12] ~= false
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
    local contextOptions = {}
    
    table.insert(contextOptions, {
        title = ' Spawn Mounted Bandits',
        description = 'Spawn bandits on horses at your location',
        icon = 'fas fa-horse',
        onSelect = function()
            local input = lib.inputDialog('Spawn Mounted Bandits', {
                {type = 'number', label = 'Number of Bandits', default = 3, min = 1, max = 10, required = true}
            })
            
            if input and input[1] then
                local coords = GetEntityCoords(PlayerPedId())
                spawnBanditsAtLocation(coords, input[1], 0, true)
            end
        end
    })
    
    table.insert(contextOptions, {
        title = ' Spawn Bandits on Foot',
        description = 'Spawn bandits without horses at your location',
        icon = 'fas fa-walking',
        onSelect = function()
            local input = lib.inputDialog('Spawn Bandits on Foot', {
                {type = 'number', label = 'Number of Bandits', default = 3, min = 1, max = 10, required = true}
            })
            
            if input and input[1] then
                local coords = GetEntityCoords(PlayerPedId())
                spawnBanditsAtLocation(coords, input[1], 0, false)
            end
        end
    })
    
    table.insert(contextOptions, {
        title = ' Spawn Mixed Bandits',
        description = 'Spawn a mix of mounted and on-foot bandits',
        icon = 'fas fa-dice',
        onSelect = function()
            local input = lib.inputDialog('Spawn Mixed Bandits', {
                {type = 'number', label = 'Total Number of Bandits', default = 6, min = 2, max = 10, required = true},
                {type = 'number', label = 'Percentage Mounted (0-100)', default = 50, min = 0, max = 100, required = true}
            })
            
            if input and input[1] then
                local coords = GetEntityCoords(PlayerPedId())
                local total = input[1]
                local percentMounted = input[2] / 100
                local mounted = math.floor(total * percentMounted)
                local onFoot = total - mounted
                
                -- Spawn mounted bandits
                if mounted > 0 then
                    spawnBanditsAtLocation(coords, mounted, 0, true)
                end
                
                -- Spawn on-foot bandits
                if onFoot > 0 then
                    spawnBanditsAtLocation(coords, onFoot, 0, false)
                end
            end
        end
    })
    
    table.insert(contextOptions, {
        title = 'Delete All Admin Bandits',
        description = 'Remove all admin spawned bandits and horses',
        icon = 'fas fa-trash',
        onSelect = function()
            deleteAllAdminBandits()
        end
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
        title = 'Bandit Admin Menu',
        options = contextOptions
    })
    
    lib.showContext('bandit_admin_menu')
end

function openSavedLocationsMenu()
    local contextOptions = {}
    
    for i, location in ipairs(tempBanditLocations) do
        local statusIcon = location.enabled and '??' or '??'
        local banditIcon = ''
        if location.banditType == 'mounted' then
            banditIcon = '??'
        elseif location.banditType == 'foot' then
            banditIcon = '??'
        else
            banditIcon = '??'
        end
        
        table.insert(contextOptions, {
            title = statusIcon .. ' ' .. banditIcon .. ' ' .. location.name,
            description = 'Type: ' .. location.banditType .. ' | Count: ' .. location.banditCount .. ' | Proximity: ' .. location.proximity .. 'm | By: ' .. (location.createdBy or 'Unknown'),
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
    local contextOptions = {}
    
    local typeIcon = location.banditType == 'mounted' and '??' or location.banditType == 'foot' and '??' or '??'
    
    table.insert(contextOptions, {
        title = 'Spawn Bandits Here',
        description = typeIcon .. ' Type: ' .. location.banditType .. ' | Count: ' .. location.banditCount .. (location.timer > 0 and ' | Timer: ' .. location.timer .. 's' or ''),
        icon = 'fas fa-user-ninja',
        onSelect = function()
            local input = lib.inputDialog('Spawn Bandits', {
                {type = 'number', label = 'Number of Bandits', default = location.banditCount or 3, min = 1, max = 10, required = true},
                {type = 'select', label = 'Override Type', options = {
                    {value = 'default', label = 'Use Saved Setting (' .. location.banditType .. ')'},
                    {value = 'mounted', label = '?? Force Mounted'},
                    {value = 'foot', label = '?? Force On Foot'},
                    {value = 'mixed', label = '?? Force Mixed'}
                }, default = 'default'}
            })
            
            if input and input[1] then
                local banditType = input[2] == 'default' and (location.banditType or 'mounted') or input[2]
                
                if banditType == 'mixed' then
                    local mounted = math.floor(input[1] / 2)
                    local onFoot = input[1] - mounted
                    spawnBanditsAtLocation(location.coords, mounted, location.timer, true)
                    spawnBanditsAtLocation(location.coords, onFoot, location.timer, false)
                else
                    local isMounted = banditType == 'mounted'
                    spawnBanditsAtLocation(location.coords, input[1], location.timer, isMounted)
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
                banditType = location.banditType,
                banditCount = location.banditCount,
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

function openConfigLocationsMenu()
    local contextOptions = {}
    
    for i, banditGroup in ipairs(Config.Bandits) do
        local statusIcon = banditGroup.enabled ~= false and '??' or '??'
        local mountIcon = banditGroup.mounted ~= false and '??' or '??'
        
        table.insert(contextOptions, {
            title = statusIcon .. ' ' .. mountIcon .. ' Config Location ' .. i,
            description = 'X: ' .. math.floor(banditGroup.triggerPoint.x) .. ', Y: ' .. math.floor(banditGroup.triggerPoint.y) .. ', Z: ' .. math.floor(banditGroup.triggerPoint.z),
            icon = 'fas fa-cog',
            onSelect = function()
                local input = lib.inputDialog('Spawn Bandits', {
                    {type = 'number', label = 'Number of Bandits', default = 3, min = 1, max = 10, required = true},
                    {type = 'select', label = 'Type', options = {
                        {value = 'mounted', label = '?? Mounted'},
                        {value = 'foot', label = '?? On Foot'},
                        {value = 'mixed', label = '?? Mixed'}
                    }, default = 'mounted'}
                })
                
                if input and input[1] then
                    if input[2] == 'mixed' then
                        local mounted = math.floor(input[1] / 2)
                        local onFoot = input[1] - mounted
                        spawnBanditsAtLocation(banditGroup.triggerPoint, mounted, 0, true)
                        spawnBanditsAtLocation(banditGroup.triggerPoint, onFoot, 0, false)
                    else
                        local isMounted = input[2] == 'mounted'
                        spawnBanditsAtLocation(banditGroup.triggerPoint, input[1], 0, isMounted)
                    end
                end
            end
        })
    end
    
    lib.registerContext({
        id = 'config_locations_menu',
        title = 'Config Locations',
        menu = 'bandit_admin_menu',
        options = contextOptions
    })
    
    lib.showContext('config_locations_menu')
end

-- Proximity trigger system for saved locations
Citizen.CreateThread(function()
    while true do
        Wait(1000)
        local playerCoords = GetEntityCoords(PlayerPedId())
        local currentTime = GetGameTimer()
        
        for _, location in ipairs(tempBanditLocations) do
            if location.enabled and location.proximity > 0 and not location.isTriggered then
                if currentTime - (location.createdAt or 0) >= (location.initialDelay * 1000) then
                    if not location.lastTriggered or (currentTime - location.lastTriggered >= (location.cooldown * 1000)) then
                        local dis = GetDistanceBetweenCoords(playerCoords.x, playerCoords.y, playerCoords.z, location.coords.x, location.coords.y, location.coords.z)
                        if dis < location.proximity then
                            location.isTriggered = true
                            location.lastTriggered = currentTime
                            
                            -- Spawn based on saved bandit type
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
            elseif location.isTriggered then
                local dis = GetDistanceBetweenCoords(playerCoords.x, playerCoords.y, playerCoords.z, location.coords.x, location.coords.y, location.coords.z)
                if dis >= location.proximity * 1.5 then
                    location.isTriggered = false
                end
            end
        end
    end
end)

-- Register commands
RegisterCommand('banditmenu', function()
    openBanditMenu()
end, false)

RegisterCommand('spawnbandits', function(source, args)
    local count = tonumber(args[1]) or 3
    local banditType = args[2] or 'mounted' -- mounted, foot, or mixed
    
    if count > 10 then count = 10 end
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

RegisterCommand('deletebandits', function()
    deleteAllAdminBandits()
end, false)

RegisterCommand('addlocation', function()
    addLocationViaMenu()
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
    
    -- Clean up regular bandits
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
    
    -- Clean up regular bandit blips
    for v, k in pairs(banditBlips) do
        if DoesBlipExist(k) then
            RemoveBlip(k)
        end
    end
    
    -- Clean up admin bandits
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
    
    -- Clean up admin bandit blips
    for _, blip in pairs(adminBanditBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    
    -- Clean up location blips
    for _, location in ipairs(tempBanditLocations) do
        if location.blip and DoesBlipExist(location.blip) then
            RemoveBlip(location.blip)
        end
    end
    
    -- Clear tracked bandits
    trackedBandits = {}
end)