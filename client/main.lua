--client/main.lua

QBCore = exports['qb-core']:GetCoreObject()
PlayerData = nil
local hotbarShown = false
local isBlurEnabled = true

local function ToggleHUD(show)
    if not Config.CustomHUD or not Config.CustomHUD.Enabled then return end
    local resourceName = Config.CustomHUD.ResourceName
    local exportName = Config.CustomHUD.ExportName
    if not resourceName or not exportName then return end
    if GetResourceState(resourceName) == 'started' then
        local hudResource = exports[resourceName]
        if hudResource and type(hudResource[exportName]) == 'function' then
            hudResource[exportName](hudResource, show)
        end
    end
end
-- Handlers

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    LocalPlayer.state:set('inv_busy', false, true)
    PlayerData = QBCore.Functions.GetPlayerData()
    GetDrops()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    LocalPlayer.state:set('inv_busy', true, true)
    PlayerData = nil
end)

RegisterNetEvent('QBCore:Client:UpdateObject', function()
    QBCore = exports['qb-core']:GetCoreObject()
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    PlayerData = val
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        PlayerData = QBCore.Functions.GetPlayerData()
    end
end)

RegisterNetEvent('qb-inventory:client:sendServerTime', function(serverTime)
    SendNUIMessage({
        action = 'setServerTime',
        serverTime = serverTime
    })
end)

-- Functions

function LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return end

    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

local function FormatWeaponAttachments(itemdata)
    if not itemdata.info or not itemdata.info.attachments or #itemdata.info.attachments == 0 then
        return {}
    end
    local attachments = {}
    local weaponName = itemdata.name
    local WeaponAttachments = exports['qb-weapons']:getConfigWeaponAttachments()
    if not WeaponAttachments then return {} end
    for _, attachmentData in ipairs(itemdata.info.attachments) do
        for attachmentType, weapons in pairs(WeaponAttachments) do
            if weapons[weaponName] and weapons[weaponName] == attachmentData.component then
                local label = QBCore.Shared.Items[attachmentType] and QBCore.Shared.Items[attachmentType].label or 'Unknown Attachment'
                table.insert(attachments, {
                    attachment = attachmentType,
                    label = label
                })
                break
            end
        end
    end
    return attachments
end

--- @param items string|table - The item(s) to check for. Can be a table of items or a single item as a string.
--- @param amount number [optional] - The minimum amount required for each item. If not provided, any amount greater than 0 will be considered.
--- @return boolean - Returns true if the player has the item(s) with the specified amount, false otherwise.
function HasItem(items, amount)
    if not PlayerData or not PlayerData.items then
        return false
    end
    local requiredItems = {}
    if type(items) ~= 'table' then
        requiredItems[items] = amount or 1
    else
        if table.type(items) == 'array' then
            for _, itemName in ipairs(items) do
                requiredItems[itemName] = amount or 1
            end
        else -- Map
            for itemName, itemAmount in pairs(items) do
                requiredItems[itemName] = itemAmount
            end
        end
    end
    if not next(requiredItems) then
        return true
    end
    local playerItemCounts = {}
    for _, itemData in pairs(PlayerData.items) do
        if itemData then
            playerItemCounts[itemData.name] = (playerItemCounts[itemData.name] or 0) + itemData.amount
        end
    end
    for itemName, requiredAmount in pairs(requiredItems) do
        if (playerItemCounts[itemName] or 0) < requiredAmount then
            return false
        end
    end
    return true
end

exports('HasItem', HasItem)

-- Events

RegisterNetEvent('qb-inventory:client:requiredItems', function(items, bool)
    local itemTable = {}
    if bool then
        for k in pairs(items) do
            itemTable[#itemTable + 1] = {
                item = items[k].name,
                label = QBCore.Shared.Items[items[k].name]['label'],
                image = items[k].image,
            }
        end
    end

    SendNUIMessage({
        action = 'requiredItem',
        items = itemTable,
        toggle = bool
    })
end)

RegisterNetEvent('qb-inventory:client:hotbar', function(items)
    hotbarShown = not hotbarShown
    SendNUIMessage({
        action = 'toggleHotbar',
        open = hotbarShown,
        items = items
    })
end)

RegisterNetEvent('qb-inventory:client:closeInv', function()
    ToggleHUD(true)
    SendNUIMessage({
        action = 'close',
    })
end)

RegisterNetEvent('qb-inventory:client:updateInventory', function()
    local items = {}
    if PlayerData and type(PlayerData.items) == "table" then
        items = PlayerData.items
    end

    SendNUIMessage({
        action = 'update',
        inventory = items
    })
end)

RegisterNetEvent('qb-inventory:client:ItemBox', function(itemData, type, amount)
   -- print(('DEBUG: Received ItemBox event with item: %s'):format(json.encode(itemData)))

    SendNUIMessage({
        action = 'itemBox',
        item = itemData,
        type = type,
        amount = amount
    })
end)

RegisterNetEvent('qb-inventory:server:RobPlayer', function(TargetId)
    SendNUIMessage({
        action = 'RobMoney',
        TargetId = TargetId,
    })
end)

RegisterNetEvent('qb-inventory:client:openInventory', function(items, other)
    ToggleHUD(false)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        inventory = items,
        slots = Config.MaxSlots,
        maxweight = Config.MaxWeight,
        other = other
    })
end)

RegisterNetEvent('qb-inventory:client:giveAnim', function()
    if IsPedInAnyVehicle(PlayerPedId(), false) then return end
    LoadAnimDict('mp_common')
    TaskPlayAnim(PlayerPedId(), 'mp_common', 'givetake1_b', 8.0, 1.0, -1, 16, 0, false, false, false)
end)

-- NUI Callbacks

RegisterNUICallback('PlayDropFail', function(_, cb)
    PlaySound(-1, 'Place_Prop_Fail', 'DLC_Dmod_Prop_Editor_Sounds', 0, 0, 1)
    cb('ok')
end)

RegisterNUICallback('AttemptPurchase', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-inventory:server:attemptPurchase', function(canPurchase)
        cb(canPurchase)
    end, data)
end)

RegisterNUICallback('CloseInventory', function(data, cb)
    ToggleHUD(true)
    SetNuiFocus(false, false)
    TriggerScreenblurFadeOut(250)

    if data.name then
        if data.name:find('trunk-') then
            CloseTrunk()
        end
        TriggerServerEvent('qb-inventory:server:closeInventory', data.name)
    elseif CurrentDrop then
        TriggerServerEvent('qb-inventory:server:closeInventory', CurrentDrop)
        CurrentDrop = nil
    end
    cb('ok')
end)

RegisterNUICallback('SetBlur', function(data, cb)
    isBlurEnabled = data.enabled
    if isBlurEnabled then
        TriggerScreenblurFadeIn(250)
    else
        TriggerScreenblurFadeOut(250)
    end
    cb('ok')
end)

RegisterNUICallback('ToggleBlur', function(data, cb)
    isBlurEnabled = data.enabled
    if isBlurEnabled then
        TriggerScreenblurFadeIn(250)
    else
        TriggerScreenblurFadeOut(250)
    end
    cb('ok')
end)

RegisterNUICallback('UseItem', function(data, cb)
    TriggerServerEvent('qb-inventory:server:useItem', data.item)
    cb('ok')
end)

RegisterNUICallback('SetInventoryData', function(data, cb)
    TriggerServerEvent('qb-inventory:server:SetInventoryData', data.fromInventory, data.toInventory, data.fromSlot, data.toSlot, data.fromAmount, data.toAmount)
    cb('ok')
end)


RegisterNUICallback('GetWeaponData', function(cData, cb)
    local data = {
        WeaponData = QBCore.Shared.Items[cData.weapon],
        AttachmentData = FormatWeaponAttachments(cData.ItemData)
    }
    cb(data)
end)

RegisterNUICallback('RemoveAttachment', function(data, cb)
    local ped = PlayerPedId()
    local WeaponData = data.WeaponData
    local allAttachments = exports['qb-weapons']:getConfigWeaponAttachments()
    local Attachment = allAttachments[data.AttachmentData.attachment][WeaponData.name]
    local itemInfo = QBCore.Shared.Items[data.AttachmentData.attachment]
    QBCore.Functions.TriggerCallback('qb-weapons:server:RemoveAttachment', function(NewAttachments)
        if NewAttachments ~= false then
            local Attachies = {}
            RemoveWeaponComponentFromPed(ped, joaat(WeaponData.name), joaat(Attachment))
            for _, v in pairs(NewAttachments) do
                for attachmentType, weapons in pairs(allAttachments) do
                    local componentHash = weapons[WeaponData.name]
                    if componentHash and v.component == componentHash then
                        local label = itemInfo and itemInfo.label or 'Unknown'
                        Attachies[#Attachies + 1] = {
                            attachment = attachmentType,
                            label = label,
                        }
                    end
                end
            end
            local DJATA = {
                Attachments = Attachies,
                WeaponData = WeaponData,
                itemInfo = itemInfo,
            }
            cb(DJATA)
        else
            RemoveWeaponComponentFromPed(ped, joaat(WeaponData.name), joaat(Attachment))
            cb({})
        end
    end, data.AttachmentData, WeaponData)
end)

RegisterNUICallback('GetNearbyPlayers', function(_, cb)
    local nearbyPlayers = {}
    local playersInRadius = QBCore.Functions.GetPlayersFromCoords(GetEntityCoords(PlayerPedId()), 5.0) 

    for _, pId in ipairs(playersInRadius) do
        if pId ~= PlayerId() then 
            table.insert(nearbyPlayers, { id = GetPlayerServerId(pId), name = GetPlayerName(pId) })
        end
    end
    
    cb(nearbyPlayers)
end)

RegisterNUICallback('GiveItemToTarget', function(data, cb)
    if not data or not data.targetId then
        cb(false)
        return
    end
    QBCore.Functions.TriggerCallback('qb-inventory:server:giveItem', function(success)
        cb(success)
    end, data) 
end)

RegisterNUICallback('Notify', function(data, cb)
    if not data.message or not data.type then return end
    QBCore.Functions.Notify(data.message, data.type, data.duration or 5000)
    cb('ok')
end)

-- Vending

CreateThread(function()
    exports['qb-target']:AddTargetModel(Config.VendingObjects, {
        options = {
            {
                type = 'server',
                event = 'qb-inventory:server:openVending',
                icon = 'fa-solid fa-cash-register',
                label = Lang:t('menu.vending'),
            },
        },
        distance = 2.5
    })
end)

-- Commands

RegisterCommand('openInv', function()
    if IsNuiFocused() or IsPauseMenuActive() then return end
    ExecuteCommand('inventory')
end, false)

RegisterCommand('toggleHotbar', function()
    ExecuteCommand('hotbar')
end, false)

for i = 1, 5 do
    RegisterCommand('slot_' .. i, function()
        local itemData = PlayerData.items[i]
        if not itemData then return end
        if itemData.type == "weapon" then
            if HoldingDrop then
                return QBCore.Functions.Notify("Your already holding a bag, Go Drop it!", "error", 5500)
            end
        end
        TriggerServerEvent('qb-inventory:server:useItem', itemData)
    end, false)
    RegisterKeyMapping('slot_' .. i, Lang:t('inf_mapping.use_item') .. i, 'keyboard', i)
end

RegisterKeyMapping('openInv', Lang:t('inf_mapping.opn_inv'), 'keyboard', Config.Keybinds.Open)
RegisterKeyMapping('toggleHotbar', Lang:t('inf_mapping.tog_slots'), 'keyboard', Config.Keybinds.Hotbar)

exports('ToggleHotbar', function(state)
    isHotbarDisabled = state
end)

-- =================================================================
--                        PLAYER SEARCH FEATURE (ROB)
-- =================================================================

CreateThread(function()
    while not exports['qb-target'] do Wait(100) end
    
    exports['qb-target']:AddTargetEntity(GetGamePool('CPed'), {
        options = {
            {
                icon = 'fa-solid fa-person-circle-question',
                label = 'Search Player',
                action = function(entity)
                    local targetServerId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity))
                    if targetServerId ~= -1 then
                        TriggerServerEvent('robbery:server:initiateRob', targetServerId)
                    end
                end,
                canInteract = function(entity)
                    if not IsPedAPlayer(entity) then
                        return false
                    end
                    local targetServerId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity))
                    if targetServerId == GetPlayerServerId(PlayerId()) then
                        return false
                    end
                    local isDead = IsPedDeadOrDying(entity, 1)
                    local isHandsUp = IsEntityPlayingAnim(entity, 'missminuteman_1ig_2', 'handsup_base', 3)
                    
                    return isDead or isHandsUp
                end,
            }
        },
        distance = 2.0
    })
end)

RegisterNetEvent('qb-inventory:client:beingRobbed', function()
    local playerPed = PlayerPedId()
    if not IsPedDeadOrDying(playerPed, 1) then
        local duration = 5500
        local timer = 0
        
        local animDict = 'missminuteman_1ig_2'
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do
            Wait(10)
        end
        QBCore.Functions.Notify('Someone is searching you! Don\'t move!', 'warn', duration)
        CreateThread(function()
            while timer < duration do
                if not IsEntityPlayingAnim(playerPed, animDict, 'handsup_base', 3) then
                    TaskPlayAnim(playerPed, animDict, "handsup_base", 8.0, -8.0, -1, 49, 0, false, false, false)
                end
                timer = timer + 100
                Wait(100)
            end
        end)
    end
end)

RegisterCommand('rob', function(source, args, rawCommand)
    local closestPlayer, closestDistance = QBCore.Functions.GetClosestPlayer()
    if closestPlayer == -1 or closestDistance > 2.5 then
        QBCore.Functions.Notify('No one nearby to rob.', 'error')
        return
    end
    local targetServerId = GetPlayerServerId(closestPlayer)
    TriggerServerEvent('robbery:server:initiateRob', targetServerId)
end, false)

RegisterNetEvent('robbery:client:startRobberyProgress', function(targetServerId)
    QBCore.Functions.Progressbar('player_robbery', 'Searching Person...', 5000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = 'random@shop_robbery',
        anim = 'robbery_action_b',
        flags = 16,
    }, {}, {}, function() -- onFinish
        StopAnimTask(PlayerPedId(), 'random@shop_robbery', 'robbery_action_b', 1.0)
        TriggerServerEvent('qb-inventory:server:robPlayer', targetServerId)
    end, function() -- onCancel
        StopAnimTask(PlayerPedId(), 'random@shop_robbery', 'robbery_action_b', 1.0)
        QBCore.Functions.Notify('Action canceled', 'error')
    end)
end)

RegisterNetEvent('robbery:client:checkIfHandsUp', function(robberServerId)
    local playerPed = PlayerPedId()
    local isHandsUp = IsEntityPlayingAnim(playerPed, 'missminuteman_1ig_2', 'handsup_base', 3)
    TriggerServerEvent('robbery:server:handsUpResult', robberServerId, isHandsUp)
end)