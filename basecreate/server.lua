-- Enhanced Base Crafting System for FiveM Zombie Server
-- Server-side implementation

local playerBases = {}

-- Configuration
local Config = {
    maxBasesPerPlayer = 1,
    baseRadius = 50.0,
    minDistanceBetweenBases = 100.0,
    saveFile = "bases.json"
}

-- Base structure definitions
local baseStructures = {
    ["small_wall"] = {
        name = "Small Wall",
        model = "prop_fnclink_05crnr1",
        category = "Walls",
        description = "A small defensive wall"
    },
    ["large_wall"] = {
        name = "Large Wall",
        model = "prop_fnclink_09b",
        category = "Walls",
        description = "A large defensive wall"
    },
    ["corner_wall"] = {
        name = "Corner Wall",
        model = "prop_fnclink_05crnr1",
        category = "Walls",
        description = "Corner piece for walls"
    },
    ["gate"] = {
        name = "Gate",
        model = "prop_fnclink_05gate5",
        category = "Walls",
        description = "Entrance gate for your base"
    },
    ["watchtower"] = {
        name = "Watch Tower",
        model = "prop_watchtower_01",
        category = "Defense",
        description = "High vantage point for surveillance"
    },
    ["barricade"] = {
        name = "Barricade",
        model = "prop_barrier_work05",
        category = "Defense",
        description = "Quick defensive barrier"
    },
    ["sandbags"] = {
        name = "Sandbags",
        model = "prop_barrier_work06a",
        category = "Defense",
        description = "Sandbag fortification"
    },
    ["storage_small"] = {
        name = "Small Storage",
        model = "prop_toolchest_01",
        category = "Storage",
        description = "Small storage container"
    },
    ["storage_large"] = {
        name = "Large Storage",
        model = "prop_container_01a",
        category = "Storage",
        description = "Large storage container"
    },
    ["workbench"] = {
        name = "Workbench",
        model = "prop_toolchest_05",
        category = "Utility",
        description = "Crafting workbench"
    },
    ["generator"] = {
        name = "Generator",
        model = "prop_generator_01a",
        category = "Utility",
        description = "Power generator"
    },
    ["campfire"] = {
        name = "Campfire",
        model = "prop_beach_fire",
        category = "Utility",
        description = "Cooking and warmth"
    },
    ["tent"] = {
        name = "Tent",
        model = "prop_skid_tent_01",
        category = "Shelter",
        description = "Basic shelter"
    },
    ["sleeping_bag"] = {
        name = "Sleeping Bag",
        model = "prop_skid_sleepbag_1",
        category = "Shelter",
        description = "Place to rest"
    }
}

-- Initialize base system
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        loadBases()
        print("^2[Base System] ^7Enhanced base crafting system initialized")
    end
end)

-- Save bases on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        saveBases()
    end
end)

-- Command to create base
RegisterCommand('basecreate', function(source, args, rawCommand)
    local playerId = source
    local playerName = GetPlayerName(playerId)
    
    if not playerId or playerId == 0 then
        return
    end
    
    -- Check if player already has a base
    if playerBases[playerId] and playerBases[playerId].structures and tablelength(playerBases[playerId].structures) > 0 then
        TriggerClientEvent('basesystem:showNotification', playerId, "You already have a base! Use /basemanage to modify it.", "error")
        return
    end
    
    -- Get player position
    local playerPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    
    -- Check if location is suitable for base
    if not isLocationSuitable(playerCoords, playerId) then
        TriggerClientEvent('basesystem:showNotification', playerId, "This location is not suitable for a base. Try another location.", "error")
        return
    end
    
    -- Open base creation menu
    TriggerClientEvent('basesystem:openBaseCreation', playerId, playerCoords)
end, false)

-- Handle base creation with name
RegisterNetEvent('basesystem:createBaseWithName')
AddEventHandler('basesystem:createBaseWithName', function(baseName, coords)
    local playerId = source
    local playerName = GetPlayerName(playerId)
    
    if not baseName or baseName == "" then
        baseName = playerName .. "'s Base"
    end
    
    -- Initialize player base
    playerBases[playerId] = {
        owner = playerId,
        ownerName = playerName,
        baseName = baseName,
        center = coords,
        structures = {},
        created = os.time()
    }
    
    -- Create blip on client side
    TriggerClientEvent('basesystem:createBaseBlip', playerId, coords, baseName)
    
    TriggerClientEvent('basesystem:showNotification', playerId, "Base '" .. baseName .. "' created successfully!", "success")
    TriggerClientEvent('basesystem:openBuildMenu', playerId, playerBases[playerId], baseStructures)
    
    saveBases()
end)

-- Command to manage existing base
RegisterCommand('basemanage', function(source, args, rawCommand)
    local playerId = source
    
    if not playerBases[playerId] then
        TriggerClientEvent('basesystem:showNotification', playerId, "You don't have a base! Use /basecreate to create one.", "error")
        return
    end
    
    TriggerClientEvent('basesystem:openBuildMenu', playerId, playerBases[playerId], baseStructures)
end, false)

-- Command to delete base
RegisterCommand('basedelete', function(source, args, rawCommand)
    local playerId = source
    
    if not playerBases[playerId] then
        TriggerClientEvent('basesystem:showNotification', playerId, "You don't have a base to delete!", "error")
        return
    end
    
    TriggerClientEvent('basesystem:confirmBaseDelete', playerId, playerBases[playerId].baseName)
end, false)

-- Handle base deletion confirmation
RegisterNetEvent('basesystem:deleteBaseConfirmed')
AddEventHandler('basesystem:deleteBaseConfirmed', function()
    local playerId = source
    
    if not playerBases[playerId] then
        return
    end
    
    -- Delete all structures
    if playerBases[playerId].structures then
        for _, structure in pairs(playerBases[playerId].structures) do
            if DoesEntityExist(structure.entity) then
                DeleteEntity(structure.entity)
            end
        end
    end
    
    local baseName = playerBases[playerId].baseName
    
    -- Remove blip on client side
    TriggerClientEvent('basesystem:removeBaseBlip', playerId)
    
    -- Remove base data
    playerBases[playerId] = nil
    
    TriggerClientEvent('basesystem:showNotification', playerId, "Base '" .. baseName .. "' has been deleted successfully!", "success")
    
    saveBases()
end)

-- Handle structure placement
RegisterNetEvent('basesystem:placeStructure')
AddEventHandler('basesystem:placeStructure', function(structureType, position, rotation)
    local playerId = source
    
    if not playerBases[playerId] then
        return
    end
    
    if not baseStructures[structureType] then
        return
    end
    
    -- Check if position is within base radius
    local distance = #(vector3(position.x, position.y, position.z) - playerBases[playerId].center)
    if distance > Config.baseRadius then
        TriggerClientEvent('basesystem:showNotification', playerId, "Structure is too far from base center! (Max: " .. Config.baseRadius .. "m)", "error")
        return
    end
    
    -- Create the structure
    local structureData = baseStructures[structureType]
    local entity = CreateObject(GetHashKey(structureData.model), position.x, position.y, position.z, true, true, true)
    
    if entity and entity ~= 0 then
        SetEntityRotation(entity, rotation.x, rotation.y, rotation.z, 2, true)
        FreezeEntityPosition(entity, true)
        
        -- Add to player's base
        if not playerBases[playerId].structures then
            playerBases[playerId].structures = {}
        end
        
        local structureId = #playerBases[playerId].structures + 1
        playerBases[playerId].structures[structureId] = {
            id = structureId,
            type = structureType,
            entity = entity,
            position = position,
            rotation = rotation,
            model = structureData.model
        }
        
        TriggerClientEvent('basesystem:showNotification', playerId, "Placed: " .. structureData.name, "success")
        
        saveBases()
    else
        TriggerClientEvent('basesystem:showNotification', playerId, "Failed to create structure!", "error")
    end
end)

-- Handle structure removal
RegisterNetEvent('basesystem:removeStructure')
AddEventHandler('basesystem:removeStructure', function(structureId)
    local playerId = source
    
    if not playerBases[playerId] or not playerBases[playerId].structures or not playerBases[playerId].structures[structureId] then
        return
    end
    
    local structure = playerBases[playerId].structures[structureId]
    
    if DoesEntityExist(structure.entity) then
        DeleteEntity(structure.entity)
    end
    
    playerBases[playerId].structures[structureId] = nil
    
    TriggerClientEvent('basesystem:showNotification', playerId, "Structure removed successfully!", "success")
    
    saveBases()
end)

-- Get base info
RegisterNetEvent('basesystem:getBaseInfo')
AddEventHandler('basesystem:getBaseInfo', function()
    local playerId = source
    
    if playerBases[playerId] then
        local structureCount = playerBases[playerId].structures and tablelength(playerBases[playerId].structures) or 0
        TriggerClientEvent('basesystem:showBaseInfo', playerId, {
            name = playerBases[playerId].baseName,
            owner = playerBases[playerId].ownerName,
            structures = structureCount,
            created = playerBases[playerId].created
        })
    else
        TriggerClientEvent('basesystem:showNotification', playerId, "You don't have a base!", "error")
    end
end)

-- Command to show base info
RegisterCommand('baseinfo', function(source, args, rawCommand)
    TriggerEvent('basesystem:getBaseInfo', source)
end, false)

-- Handle player connecting (restore their blip)
AddEventHandler('playerConnecting', function()
    local playerId = source
    
    -- Wait for player to fully load before creating blip
    Citizen.SetTimeout(10000, function()
        if playerBases[playerId] then
            TriggerClientEvent('basesystem:createBaseBlip', playerId, playerBases[playerId].center, playerBases[playerId].baseName)
        end
    end)
end)

-- Send base data to player when they join
RegisterNetEvent('basesystem:requestBaseData')
AddEventHandler('basesystem:requestBaseData', function()
    local playerId = source
    
    if playerBases[playerId] then
        TriggerClientEvent('basesystem:createBaseBlip', playerId, playerBases[playerId].center, playerBases[playerId].baseName)
    end
end)

-- Utility functions
function isLocationSuitable(coords, playerId)
    -- Check distance from other bases
    for otherPlayerId, baseData in pairs(playerBases) do
        if otherPlayerId ~= playerId and baseData.center then
            local distance = #(coords - baseData.center)
            if distance < Config.minDistanceBetweenBases then
                return false
            end
        end
    end
    
    -- Check if in water (basic check)
    if coords.z < 0 then
        return false
    end
    
    return true
end

function saveBases()
    local saveData = {}
    for playerId, baseData in pairs(playerBases) do
        if baseData and baseData.center then
            saveData[tostring(playerId)] = {
                owner = baseData.owner,
                ownerName = baseData.ownerName,
                baseName = baseData.baseName,
                center = baseData.center,
                created = baseData.created,
                structures = {}
            }
            
            if baseData.structures then
                for structureId, structure in pairs(baseData.structures) do
                    if structure then
                        saveData[tostring(playerId)].structures[tostring(structureId)] = {
                            id = structure.id,
                            type = structure.type,
                            position = structure.position,
                            rotation = structure.rotation,
                            model = structure.model
                        }
                    end
                end
            end
        end
    end
    
    SaveResourceFile(GetCurrentResourceName(), Config.saveFile, json.encode(saveData), -1)
    print("^2[Base System] ^7Saved " .. tablelength(playerBases) .. " bases")
end

function loadBases()
    local saveData = LoadResourceFile(GetCurrentResourceName(), Config.saveFile)
    if saveData then
        local data = json.decode(saveData)
        if data then
            for playerId, baseData in pairs(data) do
                if baseData and baseData.center then
                    local numPlayerId = tonumber(playerId)
                    if numPlayerId then
                        playerBases[numPlayerId] = {
                            owner = baseData.owner,
                            ownerName = baseData.ownerName,
                            baseName = baseData.baseName or (baseData.ownerName .. "'s Base"),
                            center = vector3(baseData.center.x, baseData.center.y, baseData.center.z),
                            created = baseData.created or os.time(),
                            structures = {}
                        }
                        
                        -- Recreate structures
                        if baseData.structures then
                            for structureId, structure in pairs(baseData.structures) do
                                if structure and structure.position and structure.model then
                                    local entity = CreateObject(GetHashKey(structure.model), 
                                        structure.position.x, structure.position.y, structure.position.z, 
                                        true, true, true)
                                    
                                    if entity and entity ~= 0 then
                                        SetEntityRotation(entity, structure.rotation.x, structure.rotation.y, structure.rotation.z, 2, true)
                                        FreezeEntityPosition(entity, true)
                                        
                                        local numStructureId = tonumber(structureId) or #playerBases[numPlayerId].structures + 1
                                        playerBases[numPlayerId].structures[numStructureId] = {
                                            id = structure.id,
                                            type = structure.type,
                                            entity = entity,
                                            position = structure.position,
                                            rotation = structure.rotation,
                                            model = structure.model
                                        }
                                    end
                                end
                            end
                        end
                    end
                end
            end
            print("^2[Base System] ^7Loaded " .. tablelength(playerBases) .. " bases")
        end
    else
        print("^3[Base System] ^7No save file found, starting fresh")
    end
end

function tablelength(T)
    local count = 0
    if T then
        for _ in pairs(T) do count = count + 1 end
    end
    return count
end

-- Clean up on player disconnect
AddEventHandler('playerDropped', function(reason)
    local playerId = source
    -- Base data is kept for when player reconnects
    -- You can add additional cleanup logic here if needed
end)

-- Admin command to list all bases
RegisterCommand('baseadmin', function(source, args, rawCommand)
    local playerId = source
    
    -- Check if player is admin (you can modify this check based on your admin system)
    if not IsPlayerAceAllowed(playerId, "command.baseadmin") then
        TriggerClientEvent('basesystem:showNotification', playerId, "You don't have permission to use this command!", "error")
        return
    end
    
    local baseCount = tablelength(playerBases)
    local message = "^2[Base System] ^7Total bases: " .. baseCount .. "\n"
    
    for playerId, baseData in pairs(playerBases) do
        local structureCount = baseData.structures and tablelength(baseData.structures) or 0
        message = message .. "^3" .. baseData.ownerName .. "^7: " .. baseData.baseName .. " (" .. structureCount .. " structures)\n"
    end
    
    print(message)
    TriggerClientEvent('chat:addMessage', playerId, {
        color = {0, 255, 0},
        multiline = true,
        args = {"[Base Admin]", "Check console for base list"}
    })
end, true)

-- Admin command to delete any base
RegisterCommand('basedeleteadmin', function(source, args, rawCommand)
    local playerId = source
    
    -- Check if player is admin
    if not IsPlayerAceAllowed(playerId, "command.baseadmin") then
        TriggerClientEvent('basesystem:showNotification', playerId, "You don't have permission to use this command!", "error")
        return
    end
    
    if not args[1] then
        TriggerClientEvent('basesystem:showNotification', playerId, "Usage: /basedeleteadmin <player_id>", "error")
        return
    end
    
    local targetPlayerId = tonumber(args[1])
    if not targetPlayerId or not playerBases[targetPlayerId] then
        TriggerClientEvent('basesystem:showNotification', playerId, "Base not found for player ID: " .. args[1], "error")
        return
    end
    
    -- Delete all structures
    if playerBases[targetPlayerId].structures then
        for _, structure in pairs(playerBases[targetPlayerId].structures) do
            if DoesEntityExist(structure.entity) then
                DeleteEntity(structure.entity)
            end
        end
    end
    
    local baseName = playerBases[targetPlayerId].baseName
    local ownerName = playerBases[targetPlayerId].ownerName
    
    -- Remove blip for the target player if they're online
    TriggerClientEvent('basesystem:removeBaseBlip', targetPlayerId)
    
    -- Remove base data
    playerBases[targetPlayerId] = nil
    
    TriggerClientEvent('basesystem:showNotification', playerId, "Deleted base '" .. baseName .. "' owned by " .. ownerName, "success")
    
    saveBases()
end, true)
