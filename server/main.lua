QBCore = exports['qb-core']:GetCoreObject()
Inventories = {}
Drops = {}
RegisteredShops = {}

Config.Debug = false -- Set to false to disable console logs

local function CopyTable(tbl)
    if type(tbl) ~= 'table' then return tbl end
    local newTbl = {}
    for k, v in pairs(tbl) do
        newTbl[k] = CopyTable(v)
    end
    return newTbl
end

CreateThread(function()
    MySQL.query('SELECT * FROM inventories', {}, function(result)
        if result and #result > 0 then
            for i = 1, #result do
                local inventory = result[i]
                local cacheKey = inventory.identifier
                Inventories[cacheKey] = {
                    items = json.decode(inventory.items) or {},
                    isOpen = false
                }
            end
            print(#result .. ' inventories successfully loaded')
        end
    end)
end)

CreateThread(function()
    while true do
        for k, v in pairs(Drops) do
            if v and (v.createdTime + (Config.CleanupDropTime * 60) < os.time()) and not Drops[k].isOpen then
                local entity = NetworkGetEntityFromNetworkId(v.entityId)
                if DoesEntityExist(entity) then DeleteEntity(entity) end
                Drops[k] = nil
            end
        end
        Wait(Config.CleanupDropInterval * 60000)
    end
end)




AddEventHandler('playerDropped', function()
    for _, inv in pairs(Inventories) do
        if inv.isOpen == source then
            inv.isOpen = false
        end
    end
end)

AddEventHandler('txAdmin:events:serverShuttingDown', function()
    for inventory, data in pairs(Inventories) do
        if data.isOpen then
            MySQL.prepare('INSERT INTO inventories (identifier, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?', { inventory, json.encode(data.items), json.encode(data.items) })
        end
    end
end)

RegisterNetEvent('QBCore:Server:UpdateObject', function()
    if source ~= '' then return end
    QBCore = exports['qb-core']:GetCoreObject()
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    
    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'AddItem', function(item, amount, slot, info, reason)
        return AddItem(Player.PlayerData.source, item, amount, slot, info, reason)
    end)

    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'RemoveItem', function(item, amount, slot, reason)
        return RemoveItem(Player.PlayerData.source, item, amount, slot, reason)
    end)

    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'GetItemBySlot', function(slot)
        return GetItemBySlot(Player.PlayerData.source, slot)
    end)

    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'GetItemByName', function(item)
        return GetItemByName(Player.PlayerData.source, item)
    end)

    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'GetItemsByName', function(item)
        return GetItemsByName(Player.PlayerData.source, item)
    end)

    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'ClearInventory', function(filterItems)
        ClearInventory(Player.PlayerData.source, filterItems)
    end)

    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'SetInventory', function(items)
        SetInventory(Player.PlayerData.source, items)
    end)

    local playerItems = Player.PlayerData.items
    if playerItems then
        local cashInInventory = 0
        for _, item in pairs(playerItems) do
            if item and item.name == 'cash' then
                cashInInventory = cashInInventory + item.amount
            end
        end
        if Player.PlayerData.money.cash ~= cashInInventory then
            print(('[qb-inventory] Player %s (%s) had desynced cash. Correcting from %s to %s.'):format(Player.PlayerData.name, Player.PlayerData.citizenid, Player.PlayerData.money.cash, cashInInventory))
            Player.Functions.SetMoney('cash', cashInInventory, 'login_sync')
        end
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    local Players = QBCore.Functions.GetPlayers()
    for k in pairs(Players) do
        QBCore.Functions.AddPlayerMethod(k, 'AddItem', function(item, amount, slot, info)
            return AddItem(k, item, amount, slot, info)
        end)

        QBCore.Functions.AddPlayerMethod(k, 'RemoveItem', function(item, amount, slot)
            return RemoveItem(k, item, amount, slot)
        end)

        QBCore.Functions.AddPlayerMethod(k, 'GetItemBySlot', function(slot)
            return GetItemBySlot(k, slot)
        end)

        QBCore.Functions.AddPlayerMethod(k, 'GetItemByName', function(item)
            return GetItemByName(k, item)
        end)

        QBCore.Functions.AddPlayerMethod(k, 'GetItemsByName', function(item)
            return GetItemsByName(k, item)
        end)

        QBCore.Functions.AddPlayerMethod(k, 'ClearInventory', function(filterItems)
            ClearInventory(k, filterItems)
        end)

        QBCore.Functions.AddPlayerMethod(k, 'SetInventory', function(items)
            SetInventory(k, items)
        end)

        Player(k).state.inv_busy = false
    end
end)



local function checkWeapon(source, item)
    local currentWeapon = type(item) == 'table' and item.name or item
    local ped = GetPlayerPed(source)
    local weapon = GetSelectedPedWeapon(ped)
    local weaponInfo = QBCore.Shared.Weapons[weapon]
    if weaponInfo and weaponInfo.name == currentWeapon then
        RemoveWeaponFromPed(ped, weapon)
        TriggerClientEvent('qb-weapons:client:UseWeapon', source, { name = currentWeapon }, false)
    end
end



RegisterNetEvent('qb-inventory:server:openVending', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    CreateShop({
        name = 'vending',
        label = 'Vending Machine',
        coords = data.coords,
        slots = #Config.VendingItems,
        items = Config.VendingItems
    })
    TriggerClientEvent('qb-inventory:client:sendServerTime', source, os.time())
    OpenShop(src, 'vending')
end)

local function GetItemCountInMap(items)
    if not items then return 0 end
    local count = 0
    for _ in pairs(items) do
        count = count + 1
    end
    return count
end

RegisterNetEvent('qb-inventory:server:closeInventory', function(inventory)
    local src = source
    local QBPlayer = QBCore.Functions.GetPlayer(src)
    if not QBPlayer then return end
    Player(source).state.inv_busy = false
    if inventory:find('shop%-') then return end
    if inventory:find('otherplayer%-') then
        local targetId = tonumber(inventory:match('otherplayer%-(.+)'))
        Player(targetId).state.inv_busy = false
        return
    end
    if Drops[inventory] then
        Drops[inventory].isOpen = false
        if GetItemCountInMap(Drops[inventory].items) == 0 and not Drops[inventory].isOpen then 
            if Config.Debug then print(('[INV_DEBUG_SERVER] Drop bag %s is empty, deleting.'):format(inventory)) end
            TriggerClientEvent('qb-inventory:client:removeDropTarget', -1, Drops[inventory].entityId)
            Wait(500)
            local entity = NetworkGetEntityFromNetworkId(Drops[inventory].entityId)
            if DoesEntityExist(entity) then DeleteEntity(entity) end
            Drops[inventory] = nil
        else
            if Config.Debug then print(('[INV_DEBUG_SERVER] Drop bag %s is not empty (%s items), keeping it.'):format(inventory, GetItemCountInMap(Drops[inventory].items))) end
        end
        return
    end
     if not Inventories[inventory] then return end
    Inventories[inventory].isOpen = false

    CreateThread(function()
        MySQL.prepare.await('INSERT INTO inventories (identifier, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?', { inventory, json.encode(Inventories[inventory].items), json.encode(Inventories[inventory].items) })
    end)
end)

RegisterNetEvent('qb-inventory:server:useItem', function(item)
    local src = source
    local itemData = GetItemBySlot(src, item.slot)
    if not itemData then return end
    if itemData.name == 'cash' then
        return
    end
    local itemInfo = QBCore.Shared.Items[itemData.name]
    if itemData.info and itemData.info.expiryDate and os.time() >= itemData.info.expiryDate then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.item_expired'), 'error')
        return
    end
    if itemData.type == 'weapon' then
        TriggerClientEvent('qb-weapons:client:UseWeapon', src, itemData, itemData.info.quality and itemData.info.quality > 0)
        TriggerClientEvent('qb-inventory:client:ItemBox', src, itemInfo, 'use')
    elseif itemData.name == 'id_card' then
        UseItem(itemData.name, src, itemData)
        TriggerClientEvent('qb-inventory:client:ItemBox', source, itemInfo, 'use')
        local playerPed = GetPlayerPed(src)
        local playerCoords = GetEntityCoords(playerPed)
        local players = QBCore.Functions.GetPlayers()
        local gender = item.info.gender == 0 and 'Male' or 'Female'
        for _, v in pairs(players) do
            local targetPed = GetPlayerPed(v)
            local dist = #(playerCoords - GetEntityCoords(targetPed))
            if dist < 3.0 then
                TriggerClientEvent('chat:addMessage', v, {
                    template = '<div class="chat-message advert" style="background: linear-gradient(to right, rgba(5, 5, 5, 0.6), #74807c); display: flex;"><div style="margin-right: 10px;"><i class="far fa-id-card" style="height: 100%;"></i><strong> {0}</strong><br> <strong>Civ ID:</strong> {1} <br><strong>First Name:</strong> {2} <br><strong>Last Name:</strong> {3} <br><strong>Birthdate:</strong> {4} <br><strong>Gender:</strong> {5} <br><strong>Nationality:</strong> {6}</div></div>',
                    args = {
                        'ID Card',
                        item.info.citizenid,
                        item.info.firstname,
                        item.info.lastname,
                        item.info.birthdate,
                        gender,
                        item.info.nationality
                    }
                })
            end
        end
    elseif itemData.name == 'driver_license' then
        UseItem(itemData.name, src, itemData)
        TriggerClientEvent('qb-inventory:client:ItemBox', src, itemInfo, 'use')
        local playerPed = GetPlayerPed(src)
        local playerCoords = GetEntityCoords(playerPed)
        local players = QBCore.Functions.GetPlayers()
        for _, v in pairs(players) do
            local targetPed = GetPlayerPed(v)
            local dist = #(playerCoords - GetEntityCoords(targetPed))
            if dist < 3.0 then
                TriggerClientEvent('chat:addMessage', v, {
                    template = '<div class="chat-message advert" style="background: linear-gradient(to right, rgba(5, 5, 5, 0.6), #657175); display: flex;"><div style="margin-right: 10px;"><i class="far fa-id-card" style="height: 100%;"></i><strong> {0}</strong><br> <strong>First Name:</strong> {1} <br><strong>Last Name:</strong> {2} <br><strong>Birth Date:</strong> {3} <br><strong>Licenses:</strong> {4}</div></div>',
                    args = {
                        'Drivers License',
                        item.info.firstname,
                        item.info.lastname,
                        item.info.birthdate,
                        item.info.type
                    }
                }
                )
            end
        end
    else
        UseItem(itemData.name, src, itemData)
        TriggerClientEvent('qb-inventory:client:ItemBox', src, itemInfo, 'use')
    end
end)

RegisterNetEvent('qb-inventory:server:openDrop', function(dropId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    local drop = Drops[dropId]
    if not drop then return end
    if drop.isOpen then return end
    local distance = #(playerCoords - drop.coords)
    if distance > 2.5 then return end
    local formattedInventory = {
        name = dropId,
        label = dropId,
        maxweight = drop.maxweight,
        slots = drop.slots,
        inventory = drop.items
    }
    drop.isOpen = true
    TriggerClientEvent('qb-inventory:client:sendServerTime', source, os.time())
    TriggerClientEvent('qb-inventory:client:openInventory', source, Player.PlayerData.items, formattedInventory)
end)

RegisterNetEvent('qb-inventory:server:updateDrop', function(dropId, coords)
    Drops[dropId].coords = coords
end)

RegisterNetEvent('qb-inventory:server:snowball', function(action)
    if action == 'add' then
        AddItem(source, 'weapon_snowball', 1, false, false, 'qb-inventory:server:snowball')
    elseif action == 'remove' then
        RemoveItem(source, 'weapon_snowball', 1, false, 'qb-inventory:server:snowball')
    end
end)



QBCore.Functions.CreateCallback('qb-inventory:server:GetCurrentDrops', function(_, cb)
    cb(Drops)
end)

QBCore.Functions.CreateCallback('qb-inventory:server:createDrop', function(source, cb, item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        if Config.Debug then print('[INV_DEBUG_SERVER] createDrop failed: Player object not found.') end
        cb(false)
        return
    end

    local fromSlot = tonumber(item.fromSlot)
    local amountToDrop = tonumber(item.amount)

    if not fromSlot or not amountToDrop or amountToDrop <= 0 then
        if Config.Debug then print(('[INV_DEBUG_SERVER] createDrop failed: Invalid slot or amount from client. Slot: %s, Amount: %s'):format(tostring(fromSlot), tostring(amountToDrop))) end
        cb(false)
        return
    end

    if Config.Debug then print(('[INV_DEBUG_SERVER] createDrop: Processing drop of %s %s from slot %s.'):format(amountToDrop, item.name, fromSlot)) end

    local itemOnServer = Player.PlayerData.items[fromSlot]

    if not itemOnServer then
        if Config.Debug then print(('[INV_DEBUG_SERVER] createDrop failed: Slot %s is EMPTY on server.'):format(fromSlot)) end
        cb(false)
        return
    end

    if itemOnServer.name ~= item.name then
        if Config.Debug then print(('[INV_DEBUG_SERVER] createDrop failed: Item name mismatch. Client sent "%s", but server has "%s" in slot %s.'):format(item.name, itemOnServer.name, fromSlot)) end
        cb(false)
        return
    end

    if amountToDrop > itemOnServer.amount then
        if Config.Debug then print(('[INV_DEBUG_SERVER] createDrop failed: Amount mismatch. Client wants to drop %s, but server only has %s in slot %s.'):format(amountToDrop, itemOnServer.amount, fromSlot)) end
        cb(false)
        return
    end

    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)

    if RemoveItem(src, item.name, amountToDrop, fromSlot, 'dropped item') then
        if Config.Debug then print('[INV_DEBUG_SERVER] createDrop: RemoveItem successful. Creating drop object.') end
        if item.type == 'weapon' then checkWeapon(src, item) end
        TaskPlayAnim(playerPed, 'pickup_object', 'pickup_low', 8.0, -8.0, 2000, 0, 0, false, false, false)
        local bag = CreateObjectNoOffset(Config.ItemDropObject, playerCoords.x + 0.5, playerCoords.y + 0.5, playerCoords.z, true, true, false)
        local dropId = NetworkGetNetworkIdFromEntity(bag)
        local newDropId = 'drop-' .. dropId
        
        local itemsTable = {}
        local newItemForDrop = CopyTable(itemOnServer)
        newItemForDrop.amount = amountToDrop
        newItemForDrop.slot = 1
        itemsTable[1] = newItemForDrop

        if not Drops[newDropId] then
            Drops[newDropId] = {
                name = newDropId,
                label = 'Drop',
                items = itemsTable,
                entityId = dropId,
                createdTime = os.time(),
                coords = playerCoords,
                maxweight = Config.DropSize.maxweight,
                slots = Config.DropSize.slots,
                isOpen = true
            }
            TriggerClientEvent('qb-inventory:client:setupDropTarget', -1, dropId)
        else
            local freeSlot = GetFirstFreeSlot(Drops[newDropId].items, Drops[newDropId].slots)
            if freeSlot then
                newItemForDrop.slot = freeSlot
                Drops[newDropId].items[freeSlot] = newItemForDrop
            end
        end
        
        local responseData = {
            netId = dropId,
            dropData = {
                name = newDropId,
                label = 'Drop',
                maxweight = Config.DropSize.maxweight,
                slots = Config.DropSize.slots,
                inventory = itemsTable
            }
        }
        cb(responseData)
    else
        if Config.Debug then print(('[INV_DEBUG_SERVER] createDrop failed: RemoveItem returned false unexpectedly for item %s, amount %s, slot %s'):format(item.name, amountToDrop, fromSlot)) end
        cb(false)
    end
end)

QBCore.Functions.CreateCallback('qb-inventory:server:attemptPurchase', function(source, cb, data)
    local itemInfo = data.item
    local amount = data.amount
    local shop = string.gsub(data.shop, 'shop%-', '')
    local Player = QBCore.Functions.GetPlayer(source)

    if not Player then
        cb(false)
        return
    end

    local shopInfo = RegisteredShops[shop]
    if not shopInfo then
        cb(false)
        return
    end

    local playerPed = GetPlayerPed(source)
    local playerCoords = GetEntityCoords(playerPed)
    if shopInfo.coords then
        local shopCoords = vector3(shopInfo.coords.x, shopInfo.coords.y, shopInfo.coords.z)
        if #(playerCoords - shopCoords) > 10 then
            cb(false)
            return
        end
    end

    if shopInfo.items[itemInfo.slot].name ~= itemInfo.name then
        cb(false)
        return
    end

    if amount > shopInfo.items[itemInfo.slot].amount then
        TriggerClientEvent('QBCore:Notify', source, 'Cannot purchase larger quantity than currently in stock', 'error')
        cb(false)
        return
    end

    if not CanAddItem(source, itemInfo.name, amount) then
        TriggerClientEvent('QBCore:Notify', source, 'Cannot hold item', 'error')
        cb(false)
        return
    end

    local price = shopInfo.items[itemInfo.slot].price * amount
     
    if price == 0 then
        
        if AddItem(source, itemInfo.name, amount, nil, itemInfo.info, 'shop-purchase-free') then
            TriggerEvent('qb-shops:server:UpdateShopItems', shop, itemInfo, amount)
            TriggerClientEvent('qb-inventory:client:updateInventory', source)
            cb(true)
        else
            
            TriggerClientEvent('QBCore:Notify', source, 'Transaction failed, could not add item.', 'error')
            cb(false)
        end
        return 
    end
    

    if HasItem(source, 'cash', price) then
        if RemoveItem(source, 'cash', price, nil, 'shop-purchase') then
            AddItem(source, itemInfo.name, amount, nil, itemInfo.info, 'shop-purchase')
            TriggerEvent('qb-shops:server:UpdateShopItems', shop, itemInfo, amount)
            TriggerClientEvent('qb-inventory:client:updateInventory', source)
            cb(true)
        else
            TriggerClientEvent('QBCore:Notify', source, 'Transaction failed, You do not have enough cash.', 'error')
            cb(false)
        end
    else
        TriggerClientEvent('QBCore:Notify', source, 'You do not have enough money', 'error')
        cb(false)
    end
end)

QBCore.Functions.CreateCallback('qb-inventory:server:giveItem', function(source, cb, data)
    local player = QBCore.Functions.GetPlayer(source)
    local targetId = tonumber(data.targetId)
    local Target = QBCore.Functions.GetPlayer(targetId)
    
    if not player or player.PlayerData.metadata['isdead'] or player.PlayerData.metadata['inlaststand'] or player.PlayerData.metadata['ishandcuffed'] then
        cb(false)
        return
    end

    if not Target or Target.PlayerData.metadata['isdead'] or Target.PlayerData.metadata['inlaststand'] or Target.PlayerData.metadata['ishandcuffed'] then
        cb(false)
        return
    end
    local pCoords = GetEntityCoords(GetPlayerPed(source))
    local tCoords = GetEntityCoords(GetPlayerPed(targetId))
    if #(pCoords - tCoords) > 5.0 then
        cb(false)
        return
    end

    local item = data.item.name
    local amount = tonumber(data.amount)
    local slot = data.slot
    local info = data.item.info
    local itemInfo = QBCore.Shared.Items[item:lower()]

    if not itemInfo or not HasItem(source, item, amount) then
        cb(false)
        return
    end

    if RemoveItem(source, item, amount, slot, 'Item given to ID #' .. targetId) then
        if AddItem(targetId, item, amount, false, info, 'Item received from ID #' .. source) then
            if itemInfo.type == 'weapon' then checkWeapon(source, item) end
            
            TriggerClientEvent('qb-inventory:client:giveAnim', source)
            TriggerClientEvent('qb-inventory:client:ItemBox', source, itemInfo, 'remove', amount)
            TriggerClientEvent('qb-inventory:client:giveAnim', targetId)
            TriggerClientEvent('qb-inventory:client:ItemBox', targetId, itemInfo, 'add', amount)
            
            if Player(targetId).state.inv_busy then
                TriggerClientEvent('qb-inventory:client:updateInventory', targetId)
            end
            
            cb(true)
        else
            AddItem(source, item, amount, slot, info, 'Failed to give item, returned.')
            cb(false)
        end
    else
        cb(false)
    end
end)

local function getItem(inventoryId, src, slot)
    local items = {}
    if inventoryId == 'player' then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player and Player.PlayerData.items then
            items = Player.PlayerData.items
        end
    elseif inventoryId:find('otherplayer-') then
        local targetId = tonumber(inventoryId:match('otherplayer%-(.+)'))
        local targetPlayer = QBCore.Functions.GetPlayer(targetId)
        if targetPlayer and targetPlayer.PlayerData.items then
            items = targetPlayer.PlayerData.items
        end
    elseif inventoryId:find('drop-') == 1 then
        if Drops[inventoryId] and Drops[inventoryId]['items'] then
            items = Drops[inventoryId]['items']
        end
    else
        if Inventories[inventoryId] and Inventories[inventoryId]['items'] then
            items = Inventories[inventoryId]['items']
        end
    end

    for _, item in pairs(items) do
        if item.slot == slot then
            return item
        end
    end
    return nil
end

local function getIdentifier(inventoryId, src)
    if inventoryId == 'player' then
        return src
    elseif inventoryId:find('otherplayer-') then
        return tonumber(inventoryId:match('otherplayer%-(.+)'))
    else
        return inventoryId
    end
end

RegisterNetEvent('qb-inventory:server:SetInventoryData', function(fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount)
    if Config.Debug then
        print(('[INV_DEBUG_SERVER] SetInventoryData Received from source: %s'):format(source))
        print(('[INV_DEBUG_SERVER] > fromInventory: %s | toInventory: %s'):format(tostring(fromInventory), tostring(toInventory)))
        print(('[INV_DEBUG_SERVER] > fromSlot: %s | toSlot: %s'):format(tostring(fromSlot), tostring(toSlot)))
        print(('[INV_DEBUG_SERVER] > fromAmount (original amount): %s | toAmount (amount moved): %s'):format(tostring(fromAmount), tostring(toAmount)))
    end
    
    local function table_copy(orig)
        local orig_type = type(orig)
        local copy
        if orig_type == 'table' then
            copy = {}
            for orig_key, orig_value in pairs(orig) do
                copy[orig_key] = orig_value
            end
        else 
            copy = orig
        end
        return copy
    end

    if toInventory:find('shop%-') then return end
    if not fromInventory or not toInventory or not fromSlot or not toSlot or not fromAmount or not toAmount then return end

    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    fromSlot, toSlot, fromAmount, toAmount = tonumber(fromSlot), tonumber(toSlot), tonumber(fromAmount), tonumber(toAmount)
    local fromItem = getItem(fromInventory, src, fromSlot)
    local toItem = getItem(toInventory, src, toSlot)
    if not fromItem then 
        if Config.Debug then print('[INV_DEBUG_SERVER] ERROR: fromItem is nil. Aborting.') end
        return 
    end
    
    if Config.Debug then
        print('[INV_DEBUG_SERVER] > fromItem: ' .. json.encode(fromItem))
        print('[INV_DEBUG_SERVER] > toItem: ' .. json.encode(toItem))
    end

    local serverFromAmount = fromItem.amount
    if toAmount > serverFromAmount then
        if Config.Debug then print(('[INV_DEBUG_SERVER] ERROR: Client tried to move %s but server only has %s. Aborting.'):format(toAmount, serverFromAmount)) end
        return
    end
    local fromItemInfo = QBCore.Shared.Items[fromItem.name]
    if fromInventory == toInventory then
        if Config.Debug then print('[INV_DEBUG_SERVER] > Action: Same Inventory Move') end
        local inventoryId = getIdentifier(fromInventory, src)
        local TargetPlayer = QBCore.Functions.GetPlayer(inventoryId)
        local isDrop = Drops[inventoryId]
        local isStash = Inventories[inventoryId]
        local inventoryItems = (TargetPlayer and TargetPlayer.PlayerData.items) or (isDrop and isDrop.items) or (isStash and isStash.items)
        if not inventoryItems then return end
        local isSplit = not toItem and toAmount < serverFromAmount
        if isSplit then
            if Config.Debug then print('[INV_DEBUG_SERVER] > Logic Path: isSplit') end
            inventoryItems[fromSlot].amount = serverFromAmount - toAmount
            local newItem = table_copy(fromItem)
            newItem.amount = toAmount
            newItem.slot = toSlot
            inventoryItems[toSlot] = newItem
        elseif toItem then
            local canStack = fromItem.name == toItem.name and not fromItemInfo.unique and (not fromItem.info.expiryDate or (fromItem.info.expiryDate and toItem.info.expiryDate and fromItem.info.expiryDate == toItem.info.expiryDate))
            if canStack then
                if Config.Debug then print('[INV_DEBUG_SERVER] > Logic Path: canStack') end
                inventoryItems[toSlot].amount = inventoryItems[toSlot].amount + toAmount
                inventoryItems[fromSlot].amount = inventoryItems[fromSlot].amount - toAmount
                if inventoryItems[fromSlot].amount <= 0 then
                    inventoryItems[fromSlot] = nil
                end
            else 
                if Config.Debug then print('[INV_DEBUG_SERVER] > Logic Path: Swap') end
                inventoryItems[fromSlot], inventoryItems[toSlot] = inventoryItems[toSlot], inventoryItems[fromSlot]
                inventoryItems[fromSlot].slot = fromSlot
                inventoryItems[toSlot].slot = toSlot
            end
        else
            if Config.Debug then print('[INV_DEBUG_SERVER] > Logic Path: Move to empty slot') end
            inventoryItems[toSlot] = fromItem
            inventoryItems[fromSlot] = nil
            inventoryItems[toSlot].slot = toSlot
        end
        if TargetPlayer then 
            TargetPlayer.Functions.SetPlayerData('items', inventoryItems) 
        elseif isDrop then
            Drops[inventoryId].items = inventoryItems
        elseif isStash then
            Inventories[inventoryId].items = inventoryItems
        end
        return
    end

    if Config.Debug then print('[INV_DEBUG_SERVER] > Action: Different Inventory Move') end
    local fromId = getIdentifier(fromInventory, src)
    local toId = getIdentifier(toInventory, src)
    local canStackAcross = toItem and fromItem.name == toItem.name and not fromItemInfo.unique and (not fromItem.info.expiryDate or (fromItem.info.expiryDate and toItem.info.expiryDate and fromItem.info.expiryDate == toItem.info.expiryDate))

    if canStackAcross then
        if Config.Debug then print('[INV_DEBUG_SERVER] > Logic Path: canStackAcross') end
        if RemoveItem(fromId, fromItem.name, toAmount, fromSlot, 'stacked item') then
            AddItem(toId, toItem.name, toAmount, toSlot, toItem.info, 'stacked item')
        end
    elseif not toItem and toAmount < serverFromAmount then
        if Config.Debug then print('[INV_DEBUG_SERVER] > Logic Path: Split across inventories') end
        if RemoveItem(fromId, fromItem.name, toAmount, fromSlot, 'split item') then
            AddItem(toId, fromItem.name, toAmount, toSlot, fromItem.info, 'split item')
        end
    else
        if toItem then
            if Config.Debug then print('[INV_DEBUG_SERVER] > Logic Path: Swap across inventories') end
            if RemoveItem(fromId, fromItem.name, serverFromAmount, fromSlot, 'swapped item') and RemoveItem(toId, toItem.name, toItem.amount, toSlot, 'swapped item') then
                AddItem(toId, fromItem.name, serverFromAmount, toSlot, fromItem.info, 'swapped item')
                AddItem(fromId, toItem.name, toItem.amount, fromSlot, toItem.info, 'swapped item')
            end
        else
            if Config.Debug then print('[INV_DEBUG_SERVER] > Logic Path: Move to empty slot across inventories') end
            if RemoveItem(fromId, fromItem.name, serverFromAmount, fromSlot, 'moved item') then
                AddItem(toId, fromItem.name, serverFromAmount, toSlot, fromItem.info, 'moved item')
            end
        end
    end
end)