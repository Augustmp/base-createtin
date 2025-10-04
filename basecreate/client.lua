-- Enhanced Base Crafting System - Client Side
-- Fixed version with basic ASCII text and improved object controls

-- Core variables
local isInBuildMode = false
local isInRemoveMode = false
local currentStructureType = nil
local previewObject = nil
local baseData = nil
local structureTypes = {}
local baseBlip = nil
local menuOpen = false

-- Configuration
local Config = {
    blipSprite = 40,
    blipColor = 2,
    blipScale = 0.8,
    maxBuildDistance = 50.0,
    previewAlpha = 150,
    moveSpeed = 0.1,        -- Speed for vertical movement
    rotateSpeed = 2.0       -- Speed for rotation
}

-- Menu system variables
local currentIndex = 1
local menuActive = false

-- Request base data when player spawns
AddEventHandler('playerSpawned', function()
    Citizen.Wait(5000) -- Wait 5 seconds for everything to load
    TriggerServerEvent('basesystem:requestBaseData')
end)

-- Handle base creation menu
RegisterNetEvent('basesystem:openBaseCreation')
AddEventHandler('basesystem:openBaseCreation', function(coords)
    openBaseNameInput(coords)
end)

-- Handle build menu
RegisterNetEvent('basesystem:openBuildMenu')
AddEventHandler('basesystem:openBuildMenu', function(playerBase, structures)
    baseData = playerBase
    structureTypes = structures
    openMainBuildMenu()
end)

-- Handle notifications
RegisterNetEvent('basesystem:showNotification')
AddEventHandler('basesystem:showNotification', function(message, type)
    if type == "error" then
        SetNotificationTextEntry("STRING")
        AddTextComponentString("~r~[Base System]~w~ " .. message)
        DrawNotification(false, false)
    elseif type == "success" then
        SetNotificationTextEntry("STRING")
        AddTextComponentString("~g~[Base System]~w~ " .. message)
        DrawNotification(false, false)
    else
        SetNotificationTextEntry("STRING")
        AddTextComponentString("~b~[Base System]~w~ " .. message)
        DrawNotification(false, false)
    end
end)

-- Handle base deletion confirmation
RegisterNetEvent('basesystem:confirmBaseDelete')
AddEventHandler('basesystem:confirmBaseDelete', function(baseName)
    openDeleteConfirmation(baseName)
end)

-- Handle base info display
RegisterNetEvent('basesystem:showBaseInfo')
AddEventHandler('basesystem:showBaseInfo', function(info)
    local createdDate = os.date("%Y-%m-%d %H:%M", info.created)
    local message = string.format(
        "~b~Base Information~w~\n" ..
        "~y~Name:~w~ %s\n" ..
        "~y~Owner:~w~ %s\n" ..
        "~y~Structures:~w~ %d\n" ..
        "~y~Created:~w~ %s",
        info.name, info.owner, info.structures, createdDate
    )
    
    SetNotificationTextEntry("STRING")
    AddTextComponentString(message)
    DrawNotification(false, false)
end)

-- Handle base blip creation
RegisterNetEvent('basesystem:createBaseBlip')
AddEventHandler('basesystem:createBaseBlip', function(coords, baseName)
    -- Remove existing blip if it exists
    if baseBlip and DoesBlipExist(baseBlip) then
        RemoveBlip(baseBlip)
    end
    
    -- Create new blip
    baseBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(baseBlip, Config.blipSprite)
    SetBlipColour(baseBlip, Config.blipColor)
    SetBlipScale(baseBlip, Config.blipScale)
    SetBlipAsShortRange(baseBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(baseName)
    EndTextCommandSetBlipName(baseBlip)
end)

-- Handle base blip removal
RegisterNetEvent('basesystem:removeBaseBlip')
AddEventHandler('basesystem:removeBaseBlip', function()
    if baseBlip and DoesBlipExist(baseBlip) then
        RemoveBlip(baseBlip)
        baseBlip = nil
    end
end)

function openBaseNameInput(coords)
    AddTextEntry('FMMC_MPM_NA', 'Enter Base Name:')
    DisplayOnscreenKeyboard(1, "FMMC_MPM_NA", "", "", "", "", "", 30)
    
    Citizen.CreateThread(function()
        while (UpdateOnscreenKeyboard() == 0) do
            DisableAllControlActions(0)
            Wait(0)
        end
        
        if (GetOnscreenKeyboardResult()) then
            local baseName = GetOnscreenKeyboardResult()
            if baseName and baseName ~= "" then
                TriggerServerEvent('basesystem:createBaseWithName', baseName, coords)
            else
                TriggerServerEvent('basesystem:createBaseWithName', GetPlayerName(PlayerId()) .. "'s Base", coords)
            end
        end
    end)
end

function openMainBuildMenu()
    local elements = {}
    
    -- Group structures by category
    local categories = {}
    for structureKey, structureData in pairs(structureTypes) do
        if not categories[structureData.category] then
            categories[structureData.category] = {}
        end
        table.insert(categories[structureData.category], {
            key = structureKey,
            data = structureData
        })
    end
    
    -- Add category options with simple text
    for categoryName, structures in pairs(categories) do
        table.insert(elements, {
            label = categoryName .. " (" .. #structures .. " items)",
            value = "category_" .. categoryName,
            category = categoryName,
            structures = structures
        })
    end
    
    -- Add management options with simple text
    table.insert(elements, {label = "Remove Structure", value = "remove_mode"})
    table.insert(elements, {label = "Base Information", value = "base_info"})
    table.insert(elements, {label = "Exit", value = "exit"})
    
    openSimpleMenu("Base Management - " .. (baseData.baseName or "Unknown Base"), elements, function(selectedIndex)
        local element = elements[selectedIndex]
        if element.value == "exit" then
            -- Do nothing, menu will close
        elseif element.value == "remove_mode" then
            enterRemoveMode()
        elseif element.value == "base_info" then
            TriggerServerEvent('basesystem:getBaseInfo')
        elseif string.sub(element.value, 1, 9) == "category_" then
            openCategoryMenu(element.category, element.structures)
        end
    end)
end

function openCategoryMenu(categoryName, structures)
    local elements = {}
    
    for _, structure in pairs(structures) do
        table.insert(elements, {
            label = structure.data.name,
            value = "place_" .. structure.key,
            structureType = structure.key,
            description = structure.data.description
        })
    end
    
    table.insert(elements, {label = "Back", value = "back"})
    
    openSimpleMenu(categoryName .. " Structures", elements, function(selectedIndex)
        local element = elements[selectedIndex]
        if element.value == "back" then
            openMainBuildMenu()
        elseif string.sub(element.value, 1, 6) == "place_" then
            enterBuildMode(element.structureType)
        end
    end)
end

function openDeleteConfirmation(baseName)
    local elements = {
        {label = "Yes, Delete Base", value = "confirm"},
        {label = "No, Cancel", value = "cancel"}
    }
    
    openSimpleMenu("Delete '" .. baseName .. "'?", elements, function(selectedIndex)
        local element = elements[selectedIndex]
        if element.value == "confirm" then
            TriggerServerEvent('basesystem:deleteBaseConfirmed')
        end
    end)
end

-- FIXED MENU SYSTEM
function openSimpleMenu(title, elements, onSelect)
    currentIndex = 1
    menuActive = true
    menuOpen = true
    
    -- Debug notification
    SetNotificationTextEntry("STRING")
    AddTextComponentString("~b~[Debug]~w~ Menu opened. Use UP/DOWN arrows and ENTER to navigate.")
    DrawNotification(false, false)
    
    Citizen.CreateThread(function()
        while menuActive do
            Wait(0)
            
            -- Draw menu background
            DrawRect(0.5, 0.5, 0.4, 0.6, 0, 0, 0, 200)
            
            -- Draw title
            SetTextFont(0) -- Basic font
            SetTextProportional(0)
            SetTextColour(255, 255, 255, 255)
            SetTextEntry("STRING")
            SetTextCentre(true)
            SetTextScale(0.5, 0.5)
            AddTextComponentString(title)
            DrawText(0.5, 0.25)
            
            -- Draw menu items
            for i, element in ipairs(elements) do
                local yPos = 0.35 + (i - 1) * 0.04
                local color = {255, 255, 255, 255}
                
                if i == currentIndex then
                    DrawRect(0.5, yPos, 0.35, 0.03, 255, 255, 255, 50)
                    color = {0, 0, 0, 255}
                end
                
                SetTextFont(0) -- Basic font
                SetTextProportional(0)
                SetTextColour(color[1], color[2], color[3], color[4])
                SetTextEntry("STRING")
                SetTextCentre(true)
                SetTextScale(0.35, 0.35)
                AddTextComponentString(element.label)
                DrawText(0.5, yPos - 0.01)
            end
            
            -- Instructions with simple text
            SetTextFont(0) -- Basic font
            SetTextProportional(0)
            SetTextColour(200, 200, 200, 255)
            SetTextEntry("STRING")
            SetTextCentre(true)
            SetTextScale(0.3, 0.3)
            AddTextComponentString("UP/DOWN Navigate | ENTER Select | BACKSPACE Back")
            DrawText(0.5, 0.75)
            
            -- FIXED CONTROLS - Check all possible control combinations
            -- Up navigation
            if IsControlJustPressed(0, 172) or IsControlJustPressed(0, 188) then -- Up Arrow
                currentIndex = currentIndex - 1
                if currentIndex < 1 then
                    currentIndex = #elements
                end
                PlaySoundFrontend(-1, "NAV_UP_DOWN", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
            end
            
            -- Down navigation
            if IsControlJustPressed(0, 173) or IsControlJustPressed(0, 187) then -- Down Arrow
                currentIndex = currentIndex + 1
                if currentIndex > #elements then
                    currentIndex = 1
                end
                PlaySoundFrontend(-1, "NAV_UP_DOWN", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
            end
            
            -- Select
            if IsControlJustPressed(0, 201) or IsControlJustPressed(0, 18) then -- Enter
                PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
                menuActive = false
                menuOpen = false
                if onSelect then
                    onSelect(currentIndex)
                end
            end
            
            -- Back
            if IsControlJustPressed(0, 177) or IsControlJustPressed(0, 194) then -- Backspace
                PlaySoundFrontend(-1, "BACK", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
                menuActive = false
                menuOpen = false
            end
            
            -- Debug info
            SetTextFont(0) -- Basic font
            SetTextProportional(0)
            SetTextColour(255, 255, 0, 255)
            SetTextEntry("STRING")
            SetTextCentre(true)
            SetTextScale(0.3, 0.3)
            AddTextComponentString("Current Index: " .. currentIndex .. " / " .. #elements)
            DrawText(0.5, 0.8)
        end
    end)
end

function enterBuildMode(structureType)
    if not structureTypes[structureType] then
        return
    end
    
    isInBuildMode = true
    currentStructureType = structureType
    
    -- Create preview object
    local model = structureTypes[structureType].model
    RequestModel(GetHashKey(model))
    
    local timeout = 0
    while not HasModelLoaded(GetHashKey(model)) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end
    
    if not HasModelLoaded(GetHashKey(model)) then
        TriggerEvent('basesystem:showNotification', "Failed to load structure model!", "error")
        isInBuildMode = false
        return
    end
    
    local playerCoords = GetEntityCoords(PlayerPedId())
    previewObject = CreateObject(GetHashKey(model), playerCoords.x, playerCoords.y, playerCoords.z, false, false, false)
    
    if previewObject and DoesEntityExist(previewObject) then
        -- Make object semi-transparent
        SetEntityAlpha(previewObject, Config.previewAlpha, false)
        SetEntityCollision(previewObject, false, false)
        
        TriggerEvent('basesystem:showNotification', "Building: " .. structureTypes[structureType].name, "info")
        startBuildLoop()
    else
        TriggerEvent('basesystem:showNotification', "Failed to create preview object!", "error")
        isInBuildMode = false
    end
end

function startBuildLoop()
    Citizen.CreateThread(function()
        local verticalOffset = 0.0
        local rotX = 0.0
        local rotY = 0.0
        local rotZ = 0.0
        
        while isInBuildMode do
            Wait(0)
            
            if previewObject and DoesEntityExist(previewObject) then
                -- Update preview position
                local hit, coords, entity = RayCastGamePlayCamera(10.0)
                if hit then
                    -- Apply vertical offset
                    coords = vector3(coords.x, coords.y, coords.z + verticalOffset)
                    
                    SetEntityCoords(previewObject, coords.x, coords.y, coords.z, false, false, false, false)
                    
                    -- IMPROVED CONTROLS
                    
                    -- Vertical movement (PageUp/PageDown)
                    if IsControlPressed(0, 10) then -- Page Up
                        verticalOffset = verticalOffset + Config.moveSpeed
                    elseif IsControlPressed(0, 11) then -- Page Down
                        verticalOffset = verticalOffset - Config.moveSpeed
                    end
                    
                    -- Rotation controls
                    -- Z-axis rotation (A/D or Left/Right)
                    if IsControlPressed(0, 34) or IsControlPressed(0, 174) then -- A key or Left Arrow
                        rotZ = rotZ + Config.rotateSpeed
                    elseif IsControlPressed(0, 35) or IsControlPressed(0, 175) then -- D key or Right Arrow
                        rotZ = rotZ - Config.rotateSpeed
                    end
                    
                    -- X-axis rotation (W/S or Up/Down)
                    if IsControlPressed(0, 32) or IsControlPressed(0, 172) then -- W key or Up Arrow
                        rotX = rotX + Config.rotateSpeed
                    elseif IsControlPressed(0, 33) or IsControlPressed(0, 173) then -- S key or Down Arrow
                        rotX = rotX - Config.rotateSpeed
                    end
                    
                    -- Y-axis rotation (Q/E)
                    if IsControlPressed(0, 44) then -- Q key
                        rotY = rotY + Config.rotateSpeed
                    elseif IsControlPressed(0, 38) then -- E key
                        rotY = rotY - Config.rotateSpeed
                    end
                    
                    -- Reset rotation (R key)
                    if IsControlJustPressed(0, 45) then -- R key
                        rotX = 0.0
                        rotY = 0.0
                        rotZ = 0.0
                        verticalOffset = 0.0
                    end
                    
                    -- Apply rotation
                    SetEntityRotation(previewObject, rotX, rotY, rotZ, 2, true)
                    
                    -- Check distance from base center
                    local distance = 0
                    if baseData and baseData.center then
                        distance = #(coords - vector3(baseData.center.x, baseData.center.y, baseData.center.z))
                    end
                    
                    -- Instructions
                    DrawText2D(0.5, 0.05, "Building: " .. (structureTypes[currentStructureType] and structureTypes[currentStructureType].name or "Unknown"))
                    DrawText2D(0.5, 0.08, "ENTER: Place | BACKSPACE: Cancel")
                    DrawText2D(0.5, 0.11, "PAGE UP/DOWN: Move Up/Down")
                    DrawText2D(0.5, 0.14, "A/D: Rotate Z | W/S: Rotate X | Q/E: Rotate Y | R: Reset")
                    
                    -- Show distance from base center
                    if baseData and baseData.center then
                        local color = distance <= Config.maxBuildDistance and "~g~" or "~r~"
                        DrawText2D(0.5, 0.17, color .. "Distance from center: " .. math.floor(distance) .. "m / " .. Config.maxBuildDistance .. "m")
                    end
                    
                    -- Show height offset
                    DrawText2D(0.5, 0.20, "Height offset: " .. string.format("%.2f", verticalOffset))
                end
            end
            
            -- Place structure
            if IsControlJustPressed(0, 18) or IsControlJustPressed(0, 201) then -- Enter
                placeCurrentStructure()
            end
            
            -- Cancel
            if IsControlJustPressed(0, 194) or IsControlJustPressed(0, 177) then -- Backspace
                cancelBuildMode()
            end
        end
    end)
end

function placeCurrentStructure()
    if not previewObject or not currentStructureType then
        return
    end
    
    local coords = GetEntityCoords(previewObject)
    local rotation = GetEntityRotation(previewObject)
    
    -- Check if within range
    if baseData and baseData.center then
        local distance = #(coords - vector3(baseData.center.x, baseData.center.y, baseData.center.z))
        if distance > Config.maxBuildDistance then
            TriggerEvent('basesystem:showNotification', "Structure is too far from base center!", "error")
            return
        end
    end
    
    -- Send to server
    TriggerServerEvent('basesystem:placeStructure', currentStructureType, 
        {x = coords.x, y = coords.y, z = coords.z},
        {x = rotation.x, y = rotation.y, z = rotation.z}
    )
    
    cancelBuildMode()
end

function cancelBuildMode()
    isInBuildMode = false
    currentStructureType = nil
    
    if previewObject and DoesEntityExist(previewObject) then
        DeleteObject(previewObject)
        previewObject = nil
    end
    
    TriggerEvent('basesystem:showNotification', "Build mode cancelled", "info")
end

function enterRemoveMode()
    isInRemoveMode = true
    TriggerEvent('basesystem:showNotification', "Aim at a structure and press E to remove it. Press BACKSPACE to cancel.", "info")
    
    Citizen.CreateThread(function()
        while isInRemoveMode do
            Wait(0)
            
            -- Cancel remove mode
            if IsControlJustPressed(0, 194) or IsControlJustPressed(0, 177) then -- Backspace
                isInRemoveMode = false
                TriggerEvent('basesystem:showNotification', "Remove mode cancelled", "info")
                break
            end
            
            -- Remove structure
            if IsControlJustPressed(0, 38) then -- E
                local hit, coords, entity = RayCastGamePlayCamera(10.0)
                if hit and entity and entity ~= 0 and DoesEntityExist(entity) then
                    -- Find structure ID by entity
                    if baseData and baseData.structures then
                        for structureId, structure in pairs(baseData.structures) do
                            if structure.entity == entity then
                                TriggerServerEvent('basesystem:removeStructure', structureId)
                                isInRemoveMode = false
                                TriggerEvent('basesystem:showNotification', "Structure removed!", "success")
                                return
                            end
                        end
                    end
                    TriggerEvent('basesystem:showNotification', "This is not a base structure!", "error")
                end
            end
            
            -- Instructions
            DrawText2D(0.5, 0.05, "REMOVE MODE ACTIVE")
            DrawText2D(0.5, 0.08, "E: Remove Structure | BACKSPACE: Cancel")
        end
    end)
end

-- FIXED RAYCAST FUNCTION
function RayCastGamePlayCamera(distance)
    -- Get gameplay camera position and rotation
    local cameraRotation = GetGameplayCamRot()
    local cameraCoord = GetGameplayCamCoord()
    
    -- Calculate direction vector
    local direction = RotationToDirection(cameraRotation)
    
    -- Calculate end coordinates
    local destination = {
        x = cameraCoord.x + direction.x * distance,
        y = cameraCoord.y + direction.y * distance,
        z = cameraCoord.z + direction.z * distance
    }
    
    -- Perform raycast
    local handle = StartShapeTestRay(
        cameraCoord.x, cameraCoord.y, cameraCoord.z,
        destination.x, destination.y, destination.z,
        -1, PlayerPedId(), 0
    )
    
    local retval, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(handle)
    
    return hit == 1, endCoords, entityHit
end

function RotationToDirection(rotation)
    local adjustedRotation = {
        x = (math.pi / 180) * rotation.x,
        y = (math.pi / 180) * rotation.y,
        z = (math.pi / 180) * rotation.z
    }
    
    local direction = {
        x = -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        y = math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        z = math.sin(adjustedRotation.x)
    }
    
    return direction
end

function DrawText2D(x, y, text)
    SetTextFont(0) -- Basic font (0 is the most basic)
    SetTextProportional(0) -- Turn off proportional text
    SetTextScale(0.35, 0.35)
    SetTextColour(255, 255, 255, 255)
    SetTextDropShadow(0, 0, 0, 0, 255) -- Add drop shadow
    SetTextEdge(1, 0, 0, 0, 255) -- Add edge
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    DrawText(x, y)
end

-- Clean up on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if baseBlip and DoesBlipExist(baseBlip) then
            RemoveBlip(baseBlip)
        end
        if previewObject and DoesEntityExist(previewObject) then
            DeleteObject(previewObject)
        end
        menuOpen = false
        menuActive = false
        isInBuildMode = false
        isInRemoveMode = false
    end
end)
