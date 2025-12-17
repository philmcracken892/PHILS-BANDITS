local RSGCore = exports['rsg-core']:GetCoreObject()

local savedLocationsFile = "saved_locations.json"
local serverSavedLocations = {}

local triggeredConfigLocations = {}
local triggeredProximityLocations = {}

function EnsureFileExists()
    local resourcePath = GetResourcePath(GetCurrentResourceName())
    local filePath = resourcePath .. "/" .. savedLocationsFile
    
    local file = io.open(filePath, "r")
    if not file then
        file = io.open(filePath, "w")
        if file then
            file:write("[]")
            file:close()
            return true
        else
            return false
        end
    else
        file:close()
        return true
    end
end

function LoadSavedLocations()
    local resourcePath = GetResourcePath(GetCurrentResourceName())
    local filePath = resourcePath .. "/" .. savedLocationsFile
    
    local file = io.open(filePath, "r")
    if file then
        local content = file:read("*all")
        file:close()
        
        if content and content ~= "" then
            local success, decoded = pcall(json.decode, content)
            if success and decoded then
                return decoded
            else
                local backupFile = io.open(filePath .. ".backup", "w")
                if backupFile then
                    backupFile:write(content)
                    backupFile:close()
                end
                return {}
            end
        end
    end
    
    return {}
end

function SaveLocations(locations)
    local resourcePath = GetResourcePath(GetCurrentResourceName())
    local filePath = resourcePath .. "/" .. savedLocationsFile
    
    local file = io.open(filePath, "w")
    if file then
        local success, encoded = pcall(json.encode, locations, {indent = true})
        if success then
            file:write(encoded)
            file:close()
            return true
        else
            file:close()
            return false
        end
    else
        return false
    end
end

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    EnsureFileExists()
    serverSavedLocations = LoadSavedLocations()
    print("[rsg-bandits] Loaded " .. #serverSavedLocations .. " saved locations")
end)

EnsureFileExists()
serverSavedLocations = LoadSavedLocations()

RegisterNetEvent('rsg-bandits:server:getSavedLocations', function()
    local src = source
    TriggerClientEvent('rsg-bandits:client:loadSavedLocations', src, serverSavedLocations)
end)

RegisterNetEvent('rsg-bandits:server:saveLocation', function(locationData)
    local src = source
    
    if not locationData or not locationData.name or not locationData.coords then
        TriggerClientEvent('rNotify:NotifyLeft', src, "ERROR", "Invalid location data", "generic_textures", "tick", 4000)
        return
    end
    
    locationData.id = os.time() .. "_" .. math.random(1000, 9999)
    locationData.createdBy = GetPlayerName(src) or "Unknown"
    locationData.createdAt = os.time()
    
    table.insert(serverSavedLocations, locationData)
    
    if SaveLocations(serverSavedLocations) then
        TriggerClientEvent('rsg-bandits:client:loadSavedLocations', -1, serverSavedLocations)
        TriggerClientEvent('rNotify:NotifyLeft', src, "LOCATION SAVED", "'" .. locationData.name .. "' saved to server", "generic_textures", "tick", 4000)
    else
        table.remove(serverSavedLocations, #serverSavedLocations)
        TriggerClientEvent('rNotify:NotifyLeft', src, "ERROR", "Failed to save location", "generic_textures", "tick", 4000)
    end
end)

RegisterNetEvent('rsg-bandits:server:deleteLocation', function(locationId)
    local src = source
    
    if not locationId then return end
    
    for i, location in ipairs(serverSavedLocations) do
        if location.id == locationId then
            local locationName = location.name
            table.remove(serverSavedLocations, i)
            
            triggeredProximityLocations[locationId] = nil
            
            if SaveLocations(serverSavedLocations) then
                TriggerClientEvent('rsg-bandits:client:loadSavedLocations', -1, serverSavedLocations)
                TriggerClientEvent('rNotify:NotifyLeft', src, "LOCATION DELETED", "'" .. locationName .. "' removed from server", "generic_textures", "tick", 4000)
            end
            break
        end
    end
end)

RegisterNetEvent('rsg-bandits:server:updateLocation', function(locationData)
    local src = source
    
    if not locationData or not locationData.id then return end
    
    for i, location in ipairs(serverSavedLocations) do
        if location.id == locationData.id then
            locationData.createdBy = location.createdBy
            locationData.createdAt = location.createdAt
            locationData.updatedBy = GetPlayerName(src) or "Unknown"
            locationData.updatedAt = os.time()
            
            serverSavedLocations[i] = locationData
            
            if SaveLocations(serverSavedLocations) then
                TriggerClientEvent('rsg-bandits:client:loadSavedLocations', -1, serverSavedLocations)
                TriggerClientEvent('rNotify:NotifyLeft', src, "LOCATION UPDATED", "'" .. locationData.name .. "' updated", "generic_textures", "tick", 4000)
            end
            break
        end
    end
end)

-- Config Bandit Trigger System
RegisterNetEvent('rsg-bandits:server:requestConfigTrigger', function(configIndex)
    local src = source
    local currentTime = os.time()
    
    if triggeredConfigLocations[configIndex] then
        local triggerData = triggeredConfigLocations[configIndex]
        local cooldown = Config.Cooldown or 300
        
        if currentTime - triggerData.triggeredAt < cooldown then
            TriggerClientEvent('rsg-bandits:client:configTriggerDenied', src, configIndex, "Location on cooldown")
            return
        end
    end
    
    triggeredConfigLocations[configIndex] = {
        triggeredAt = currentTime,
        triggeredBy = src
    }
    
    TriggerClientEvent('rsg-bandits:client:triggerConfigBandits', src, configIndex)
    print("[rsg-bandits] Config location " .. configIndex .. " triggered by player " .. src)
end)

-- Proximity Trigger System
RegisterNetEvent('rsg-bandits:server:requestProximityTrigger', function(locationId)
    local src = source
    local currentTime = os.time()
    
    if not locationId then return end
    
    local locationData = nil
    for _, loc in ipairs(serverSavedLocations) do
        if loc.id == locationId then
            locationData = loc
            break
        end
    end
    
    if not locationData then
        TriggerClientEvent('rsg-bandits:client:proximityTriggerDenied', src, locationId, "Location not found")
        return
    end
    
    if locationData.enabled == false then
        TriggerClientEvent('rsg-bandits:client:proximityTriggerDenied', src, locationId, "Location disabled")
        return
    end
    
    if locationData.createdAt then
        local initialDelay = locationData.initialDelay or 60
        if currentTime - locationData.createdAt < initialDelay then
            TriggerClientEvent('rsg-bandits:client:proximityTriggerDenied', src, locationId, "Initial delay active")
            return
        end
    end
    
    if triggeredProximityLocations[locationId] then
        local triggerData = triggeredProximityLocations[locationId]
        local cooldown = locationData.cooldown or 300
        
        if currentTime - triggerData.triggeredAt < cooldown then
            TriggerClientEvent('rsg-bandits:client:proximityTriggerDenied', src, locationId, "Location on cooldown")
            return
        end
    end
    
    triggeredProximityLocations[locationId] = {
        triggeredAt = currentTime,
        triggeredBy = src,
        locationName = locationData.name
    }
    
    TriggerClientEvent('rsg-bandits:client:triggerProximityBandits', src, locationId, locationData)
    print("[rsg-bandits] Proximity location '" .. locationData.name .. "' triggered by player " .. src)
end)

RegisterNetEvent('rsg-bandits:server:playerLeftProximity', function(locationId)
    -- Future use
end)

-- Player rob event
RegisterNetEvent('rsg-bandits:server:robplayer', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if Player then
        local cashAmount = Player.Functions.GetMoney('cash')
        if cashAmount > 0 then
            local robbedAmount = math.floor(cashAmount * 0.25)
            Player.Functions.RemoveMoney('cash', robbedAmount)
            TriggerClientEvent('rNotify:NotifyLeft', src, "ROBBED", "You lost $" .. robbedAmount, "generic_textures", "tick", 4000)
        end
    end
end)

-- Bandit kill reward
RegisterNetEvent('rsg-bandits:server:rewardPlayer', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    if not Config.EnableRewards then return end
    
    if math.random(1, 100) > Config.RewardChance then
        return
    end
    
    local rewardMessages = {}
    
    if Config.CashReward.enabled then
        local cashAmount = math.random(Config.CashReward.min, Config.CashReward.max)
        if cashAmount > 0 then
            Player.Functions.AddMoney('cash', cashAmount)
            table.insert(rewardMessages, "$" .. cashAmount .. " cash")
        end
    end
    
    if Config.ItemRewards.enabled then
        local numItems = math.random(Config.ItemRewards.minItems, Config.ItemRewards.maxItems)
        local givenItems = {}
        
        for i = 1, numItems do
            local possibleItems = {}
            for _, itemData in ipairs(Config.ItemRewards.items) do
                if math.random(1, 100) <= itemData.chance then
                    table.insert(possibleItems, itemData)
                end
            end
            
            if #possibleItems > 0 then
                local selectedItem = possibleItems[math.random(1, #possibleItems)]
                local itemAmount = math.random(selectedItem.min, selectedItem.max)
                
                local success = Player.Functions.AddItem(selectedItem.item, itemAmount)
                if success then
                    if givenItems[selectedItem.item] then
                        givenItems[selectedItem.item] = givenItems[selectedItem.item] + itemAmount
                    else
                        givenItems[selectedItem.item] = itemAmount
                    end
                    TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items[selectedItem.item], 'add', itemAmount)
                end
            end
        end
        
        for itemName, amount in pairs(givenItems) do
            local itemLabel = RSGCore.Shared.Items[itemName] and RSGCore.Shared.Items[itemName].label or itemName
            table.insert(rewardMessages, amount .. "x " .. itemLabel)
        end
    end
    
    if #rewardMessages > 0 then
        local rewardText = table.concat(rewardMessages, ", ")
        TriggerClientEvent('rNotify:NotifyLeft', src, "BANDIT LOOT", rewardText, "generic_textures", "tick", 4000)
    end
end)

-- Zombie kill reward
RegisterNetEvent('rsg-bandits:server:rewardZombieKill', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    if not Config.ZombieRewards then return end
    
    if math.random(1, 100) > (Config.ZombieRewardChance or 60) then
        return
    end
    
    local rewardMessages = {}
    
    if Config.ZombieCashReward and Config.ZombieCashReward.enabled then
        local cashAmount = math.random(Config.ZombieCashReward.min, Config.ZombieCashReward.max)
        if cashAmount > 0 then
            Player.Functions.AddMoney('cash', cashAmount)
            table.insert(rewardMessages, "$" .. cashAmount .. " cash")
        end
    end
    
    if Config.ZombieItemRewards and Config.ZombieItemRewards.enabled then
        local numItems = math.random(Config.ZombieItemRewards.minItems, Config.ZombieItemRewards.maxItems)
        local givenItems = {}
        
        for i = 1, numItems do
            local possibleItems = {}
            for _, itemData in ipairs(Config.ZombieItemRewards.items) do
                if math.random(1, 100) <= itemData.chance then
                    table.insert(possibleItems, itemData)
                end
            end
            
            if #possibleItems > 0 then
                local selectedItem = possibleItems[math.random(1, #possibleItems)]
                local itemAmount = math.random(selectedItem.min, selectedItem.max)
                
                local success = Player.Functions.AddItem(selectedItem.item, itemAmount)
                if success then
                    if givenItems[selectedItem.item] then
                        givenItems[selectedItem.item] = givenItems[selectedItem.item] + itemAmount
                    else
                        givenItems[selectedItem.item] = itemAmount
                    end
                    TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items[selectedItem.item], 'add', itemAmount)
                end
            end
        end
        
        for itemName, amount in pairs(givenItems) do
            local itemLabel = RSGCore.Shared.Items[itemName] and RSGCore.Shared.Items[itemName].label or itemName
            table.insert(rewardMessages, amount .. "x " .. itemLabel)
        end
    end
    
    if #rewardMessages > 0 then
        local rewardText = table.concat(rewardMessages, ", ")
        TriggerClientEvent('rNotify:NotifyLeft', src, "ZOMBIE LOOT", rewardText, "generic_textures", "tick", 4000)
    end
end)

-- Admin Commands
RegisterCommand('toggleconfigbandits', function(source, args)
    if source > 0 then
        local Player = RSGCore.Functions.GetPlayer(source)
        if not Player then return end
    end
    
    Config.EnableConfigBandits = not Config.EnableConfigBandits
    TriggerClientEvent('rsg-bandits:client:updateConfigBandits', -1, Config.EnableConfigBandits)
    
    local status = Config.EnableConfigBandits and "^2enabled^0" or "^1disabled^0"
    print("[rsg-bandits] Config bandits " .. status)
    
    if source > 0 then
        TriggerClientEvent('rNotify:NotifyLeft', source, "CONFIG BANDITS", Config.EnableConfigBandits and "Enabled" or "Disabled", "generic_textures", "tick", 4000)
    end
end, false)

RegisterCommand('resetbandittriggers', function(source, args)
    if source > 0 then
        local Player = RSGCore.Functions.GetPlayer(source)
        if not Player then return end
    end
    
    triggeredConfigLocations = {}
    triggeredProximityLocations = {}
    
    print("[rsg-bandits] All trigger cooldowns reset")
    
    if source > 0 then
        TriggerClientEvent('rNotify:NotifyLeft', source, "TRIGGERS RESET", "All trigger cooldowns have been reset", "generic_textures", "tick", 4000)
    end
end, false)

RegisterCommand('bandittriggerstatus', function(source, args)
    print("[rsg-bandits] === TRIGGER STATUS ===")
    print("Config Locations Triggered: " .. tableLength(triggeredConfigLocations))
    for k, v in pairs(triggeredConfigLocations) do
        print("  - Config #" .. k .. " triggered by player " .. v.triggeredBy .. " at " .. os.date("%H:%M:%S", v.triggeredAt))
    end
    print("Proximity Locations Triggered: " .. tableLength(triggeredProximityLocations))
    for k, v in pairs(triggeredProximityLocations) do
        print("  - '" .. (v.locationName or k) .. "' triggered by player " .. v.triggeredBy .. " at " .. os.date("%H:%M:%S", v.triggeredAt))
    end
end, false)

function tableLength(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end