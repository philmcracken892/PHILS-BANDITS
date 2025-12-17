local RSGCore = exports['rsg-core']:GetCoreObject()

local savedLocationsFile = "saved_locations.json"


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
    
   
end)


local serverSavedLocations = {}


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
                -- Sync to all clients
                TriggerClientEvent('rsg-bandits:client:loadSavedLocations', -1, serverSavedLocations)
                TriggerClientEvent('rNotify:NotifyLeft', src, "LOCATION UPDATED", "'" .. locationData.name .. "' updated", "generic_textures", "tick", 4000)
            end
            break
        end
    end
end)


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

