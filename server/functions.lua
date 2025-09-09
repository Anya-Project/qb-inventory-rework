local function InitializeInventory(inventoryId, data)
    Inventories[inventoryId] = {
        items = {},
        isOpen = false,
        label = data and data.label or inventoryId,
        maxweight = data and data.maxweight or Config.StashSize.maxweight,
        slots = data and data.slots or Config.StashSize.slots
    }
    return Inventories[inventoryId]
end

local function GetFirstFreeSlot(items, maxSlots)
    for i = 1, maxSlots do
        if items[i] == nil then
            return i
        end
    end
    return nil
end

local function SetupShopItems(shopItems)
    local items = {}
    local slot = 1
    if shopItems and next(shopItems) then
        for _, item in pairs(shopItems) do
            local itemInfo = QBCore.Shared.Items[item.name:lower()]
            if itemInfo then
                items[slot] = {
                    name = itemInfo['name'],
                    amount = tonumber(item.amount),
                    info = item.info or {},
                    label = itemInfo['label'],
                    description = itemInfo['description'] or '',
                    weight = itemInfo['weight'],
                    type = itemInfo['type'],
                    unique = itemInfo['unique'],
                    useable = itemInfo['useable'],
                    price = item.price,
                    image = itemInfo['image'],
                    slot = slot,
                }
                slot = slot + 1
            end
        end
    end
    return items
end

-- Exported Functions

function LoadInventory(source, citizenid)
    local inventory = MySQL.prepare.await('SELECT inventory FROM players WHERE citizenid = ?', { citizenid })
    local loadedInventory = {}
    local missingItems = {}
    inventory = json.decode(inventory)
    if not inventory or not next(inventory) then return loadedInventory end

    for _, item in pairs(inventory) do
        if item then
            local itemInfo = QBCore.Shared.Items[item.name:lower()]

            if itemInfo then
                loadedInventory[item.slot] = {
                    name = itemInfo['name'],
                    amount = item.amount,
                    info = item.info or '',
                    label = itemInfo['label'],
                    description = itemInfo['description'] or '',
                    weight = itemInfo['weight'],
                    type = itemInfo['type'],
                    unique = itemInfo['unique'],
                    useable = itemInfo['useable'],
                    image = itemInfo['image'],
                    shouldClose = itemInfo['shouldClose'],
                    slot = item.slot,
                    combinable = itemInfo['combinable']
                }
            else
                missingItems[#missingItems + 1] = item.name:lower()
            end
        end
    end

    if #missingItems > 0 then
        print(('The following items were removed for player %s as they no longer exist: %s'):format(source and GetPlayerName(source) or citizenid, table.concat(missingItems, ', ')))
    end

    return loadedInventory
end
exports('LoadInventory', LoadInventory)

function SaveInventory(source, offline)
    print(('[qb-inventory] Save Inventory data for: %s (%s)'):format(GetPlayerName(source), source))
    local PlayerData
    if offline then
        PlayerData = source
    else
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return end
        PlayerData = Player.PlayerData
    end

    local items = PlayerData.items
    local ItemsJson = {}

    if items and next(items) then
        for slot, item in pairs(items) do
            if item then
                ItemsJson[#ItemsJson + 1] = {
                    name = item.name,
                    amount = item.amount,
                    info = item.info,
                    type = item.type,
                    slot = slot,
                }
            end
        end
        MySQL.prepare.await('UPDATE players SET inventory = ? WHERE citizenid = ?', { json.encode(ItemsJson), PlayerData.citizenid })
    else
        MySQL.prepare.await('UPDATE players SET inventory = ? WHERE citizenid = ?', { '[]', PlayerData.citizenid })
    end
end
exports('SaveInventory', SaveInventory)

function AddCash(source, amount, reason)
    if not source or not amount then return false end
    local PlayerObject = QBCore.Functions.GetPlayer(source)
    if not PlayerObject then return false end
    reason = reason or 'unknown'

    if Config.CashAsItem then
        if AddItem(source, 'cash', amount, nil, {}, 'money_as_item:add (' .. reason .. ')') then
            return true
        end
        return false
    else
        return PlayerObject.Functions.AddMoney('cash', amount, reason)
    end
end
exports('AddCash', AddCash)

function RemoveCash(source, amount, reason)
    if not source or not amount then return false end
    local PlayerObject = QBCore.Functions.GetPlayer(source)
    if not PlayerObject then return false end
    reason = reason or 'unknown'

    if Config.CashAsItem then
        if HasItem(source, 'cash', amount) then
            if RemoveItem(source, 'cash', amount, nil, 'money_as_item:remove (' .. reason .. ')') then
                return true
            end
        end
        return false
    else
        return PlayerObject.Functions.RemoveMoney('cash', amount, reason)
    end
end
exports('RemoveCash', RemoveCash)

function SetInventory(identifier, items, reason)
    local player = QBCore.Functions.GetPlayer(identifier)
    if not player and not Inventories[identifier] and not Drops[identifier] then
        print('SetInventory: Inventory not found for ' .. identifier)
        return
    end

    if player then
        player.Functions.SetPlayerData('items', items)
        ScheduleSave(identifier)
        if not player.Offline then
            local logMessage = string.format('**%s (citizenid: %s | id: %s)** items set: %s', GetPlayerName(identifier), player.PlayerData.citizenid, identifier, json.encode(items))
            TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'SetInventory', 'blue', logMessage)
        end
    elseif Drops[identifier] then
        Drops[identifier].items = items
    elseif Inventories[identifier] then
        Inventories[identifier].items = items
    end

    local invName = player and GetPlayerName(identifier) .. ' (' .. identifier .. ')' or identifier
    local setReason = reason or 'No reason specified'
    local resourceName = GetInvokingResource() or 'qb-inventory'
    TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'Inventory Set', 'blue', '**Inventory:** ' .. invName .. '\n' .. '**Items:** ' .. json.encode(items) .. '\n' .. '**Reason:** ' .. setReason .. '\n' .. '**Resource:** ' .. resourceName)
end
exports('SetInventory', SetInventory)

function SetItemData(source, itemName, key, val, slot)
    if not itemName or not key then return false end
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    local item
    if slot then
        item = Player.PlayerData.items[tonumber(slot)]
        if not item or item.name:lower() ~= itemName:lower() then return false end
    else
        item = GetItemByName(source, itemName)
        if not item then return false end
    end
    item[key] = val
    Player.PlayerData.items[item.slot] = item
    Player.Functions.SetPlayerData('items', Player.PlayerData.items)
    return true
end
exports('SetItemData', SetItemData)

function UseItem(itemName, ...)
    local itemData = QBCore.Functions.CanUseItem(itemName)
    if type(itemData) == 'table' and itemData.func then
        itemData.func(...)
    end
end
exports('UseItem', UseItem)

function GetSlotsByItem(items, itemName)
    local slotsFound = {}
    if not items then return slotsFound end
    for slot, item in pairs(items) do
        if item.name:lower() == itemName:lower() then
            slotsFound[#slotsFound + 1] = slot
        end
    end
    return slotsFound
end
exports('GetSlotsByItem', GetSlotsByItem)

function GetFirstSlotByItem(items, itemName)
    if not items then return end
    for slot, item in pairs(items) do
        if item.name:lower() == itemName:lower() then
            return tonumber(slot)
        end
    end
    return nil
end
exports('GetFirstSlotByItem', GetFirstSlotByItem)

function GetItemBySlot(source, slot)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    local items = Player.PlayerData.items
    return items[tonumber(slot)]
end
exports('GetItemBySlot', GetItemBySlot)

function GetTotalWeight(items)
    if not items then return 0 end
    local weight = 0
    for _, item in pairs(items) do
        if item and item.weight and item.amount then
            weight = weight + (item.weight * item.amount)
        end
    end
    return tonumber(weight)
end
exports('GetTotalWeight', GetTotalWeight)

function GetItemByName(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    local items = Player.PlayerData.items
    local slot = GetFirstSlotByItem(items, tostring(item):lower())
    return items[slot]
end
exports('GetItemByName', GetItemByName)

function GetItemsByName(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    local PlayerItems = Player.PlayerData.items
    item = tostring(item):lower()
    local items = {}
    for _, slot in pairs(GetSlotsByItem(PlayerItems, item)) do
        if slot then
            items[#items + 1] = PlayerItems[slot]
        end
    end
    return items
end
exports('GetItemsByName', GetItemsByName)

function GetSlots(identifier)
    local inventory, maxSlots
    local player = QBCore.Functions.GetPlayer(identifier)
    if player then
        inventory = player.PlayerData.items
        maxSlots = Config.MaxSlots
    elseif Inventories[identifier] then
        inventory = Inventories[identifier].items
        maxSlots = Inventories[identifier].slots
    elseif Drops[identifier] then
        inventory = Drops[identifier].items
        maxSlots = Drops[identifier].slots
    end
    if not inventory then return 0, maxSlots or Config.MaxSlots end
    local slotsUsed = 0
    for _, v in pairs(inventory) do
        if v then
            slotsUsed = slotsUsed + 1
        end
    end
    local slotsFree = (maxSlots or Config.MaxSlots) - slotsUsed
    return slotsUsed, slotsFree
end
exports('GetSlots', GetSlots)

function GetItemCount(source, items)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    local isTable = type(items) == 'table'
    local itemsSet = isTable and {} or nil
    if isTable then
        for _, item in pairs(items) do
            itemsSet[item] = true
        end
    end
    local count = 0
    for _, item in pairs(Player.PlayerData.items) do
        if (isTable and itemsSet[item.name]) or (not isTable and items == item.name) then
            count = count + item.amount
        end
    end
    return count
end
exports('GetItemCount', GetItemCount)

function CanAddItem(identifier, item, amount)
    local Player = QBCore.Functions.GetPlayer(identifier)
    local itemData = QBCore.Shared.Items[item:lower()]
    if not itemData then return false end

    local inventory, items
    if Player then
        inventory = { maxweight = Config.MaxWeight, slots = Config.MaxSlots }
        items = Player.PlayerData.items
    elseif Inventories[identifier] then
        inventory = Inventories[identifier]
        items = Inventories[identifier].items
    end

    if not inventory then return false end

    local weight = itemData.weight * amount
    local totalWeight = GetTotalWeight(items) + weight
    if totalWeight > inventory.maxweight then
        return false, 'weight'
    end

    if not itemData.unique then
        for _, v in pairs(items) do
            if v.name == itemData.name then
                return true
            end
        end
    end

    local slotsUsed, _ = GetSlots(identifier)
    if slotsUsed >= inventory.slots then
        return false, 'slots'
    end

    return true
end
exports('CanAddItem', CanAddItem)

function GetFreeWeight(source)
    if not source then warn('Source was not passed into GetFreeWeight') return 0 end
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return 0 end

    local totalWeight = GetTotalWeight(Player.PlayerData.items)
    return Config.MaxWeight - totalWeight
end
exports('GetFreeWeight', GetFreeWeight)

function ClearInventory(source, filterItems)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return end

    local savedItemData = {}
    if Config.CashAsItem then
        for slot, itemData in pairs(player.PlayerData.items) do
            if itemData and itemData.name == 'cash' then
                savedItemData[slot] = itemData
            end
        end
    end

    if filterItems then
        local itemsToFilter = type(filterItems) == 'string' and {filterItems} or filterItems
        for _, itemName in ipairs(itemsToFilter) do
            local items = GetItemsByName(source, itemName)
            for _, item in ipairs(items) do
                if item and not savedItemData[item.slot] then
                    savedItemData[item.slot] = item
                end
            end
        end
    end

    player.Functions.SetPlayerData('items', savedItemData)
    ScheduleSave(source)
    if not player.Offline then
        local logMessage = string.format('**%s (citizenid: %s | id: %s)** inventory cleared', GetPlayerName(source), player.PlayerData.citizenid, source)
        TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'ClearInventory', 'red', logMessage)
        local ped = GetPlayerPed(source)
        local weapon = GetSelectedPedWeapon(ped)
        if weapon ~= `WEAPON_UNARMED` then
            local weaponIsSaved = false
            for _, savedItem in pairs(savedItemData) do
                if savedItem.type == 'weapon' and QBCore.Shared.Weapons[weapon] and QBCore.Shared.Weapons[weapon].name == savedItem.name then
                    weaponIsSaved = true
                    break
                end
            end
            if not weaponIsSaved then
                RemoveWeaponFromPed(ped, weapon)
            end
        end
        if Player(source).state.inv_busy then
            TriggerClientEvent('qb-inventory:client:updateInventory', source)
        end
    end
end
exports('ClearInventory', ClearInventory)

function HasItem(source, items, amount)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not Player.PlayerData.items then return false end
    local playerItems = Player.PlayerData.items
    if type(items) ~= 'table' then
        local itemName = items
        local requiredAmount = amount or 1
        local totalAmount = 0
        for _, itemData in pairs(playerItems) do
            if itemData and itemData.name == itemName then
                totalAmount = totalAmount + itemData.amount
            end
        end
        return totalAmount >= requiredAmount
    else
        for itemName, requiredAmount in pairs(items) do
            if table.type(items) == 'array' then
                itemName = requiredAmount
                requiredAmount = amount or 1
            end
            local totalAmount = 0
            for _, itemData in pairs(playerItems) do
                if itemData and itemData.name == itemName then
                    totalAmount = totalAmount + itemData.amount
                end
            end

            if totalAmount < requiredAmount then
                return false
            end
        end
        return true
    end
end
exports('HasItem', HasItem)

function CloseInventory(source, identifier)
    if identifier and Inventories[identifier] then
        Inventories[identifier].isOpen = false
    end
    Player(source).state.inv_busy = false
    TriggerClientEvent('qb-inventory:client:closeInv', source)
end
exports('CloseInventory', CloseInventory)

function OpenInventoryById(source, targetId)
    local QBPlayer = QBCore.Functions.GetPlayer(source)
    local TargetPlayer = QBCore.Functions.GetPlayer(tonumber(targetId))
    if not QBPlayer or not TargetPlayer then return end
    if Player(targetId).state.inv_busy then CloseInventory(targetId) end
    local playerItems = QBPlayer.PlayerData.items
    local targetItems = TargetPlayer.PlayerData.items
    local formattedInventory = {
        name = 'otherplayer-' .. targetId,
        label = GetPlayerName(targetId),
        maxweight = Config.MaxWeight,
        slots = Config.MaxSlots,
        inventory = targetItems
    }
    Wait(1500)
    Player(targetId).state.inv_busy = true
    TriggerClientEvent('qb-inventory:client:openInventory', source, playerItems, formattedInventory)
end
exports('OpenInventoryById', OpenInventoryById)

function ClearStash(identifier)
    if not identifier then return end
    local inventory = Inventories[identifier]
    if not inventory then return end
    inventory.items = {}
    MySQL.prepare('UPDATE inventories SET items = ? WHERE identifier = ?', { json.encode(inventory.items), identifier })
end
exports('ClearStash', ClearStash)

function CreateShop(shopData)
    if shopData.name then
        RegisteredShops[shopData.name] = {
            name = shopData.name,
            label = shopData.label,
            coords = shopData.coords,
            slots = #shopData.items,
            items = SetupShopItems(shopData.items)
        }
    else
        for key, data in pairs(shopData) do
            if type(data) == 'table' then
                if data.name then
                    local shopName = type(key) == 'number' and data.name or key
                    RegisteredShops[shopName] = {
                        name = shopName,
                        label = data.label,
                        coords = data.coords,
                        slots = #data.items,
                        items = SetupShopItems(data.items)
                    }
                else
                    CreateShop(data)
                end
            end
        end
    end
end
exports('CreateShop', CreateShop)

function OpenShop(source, name)
    if not name then return end
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    if not RegisteredShops[name] then return end
    local playerPed = GetPlayerPed(source)
    local playerCoords = GetEntityCoords(playerPed)
    if RegisteredShops[name].coords then
        local shopDistance = vector3(RegisteredShops[name].coords.x, RegisteredShops[name].coords.y, RegisteredShops[name].coords.z)
        if shopDistance then
            if #(playerCoords - shopDistance) > 5.0 then return end
        end
    end
    local formattedInventory = {
        name = 'shop-' .. RegisteredShops[name].name,
        label = RegisteredShops[name].label,
        maxweight = 5000000,
        slots = #RegisteredShops[name].items,
        inventory = RegisteredShops[name].items
    }
    TriggerClientEvent('qb-inventory:client:sendServerTime', source, os.time())
    TriggerClientEvent('qb-inventory:client:openInventory', source, Player.PlayerData.items, formattedInventory)
end
exports('OpenShop', OpenShop)

function OpenInventory(source, identifier, data)
    if Player(source).state.inv_busy then return end
    local QBPlayer = QBCore.Functions.GetPlayer(source)
    if not QBPlayer then return end

    if not identifier then
        Player(source).state.inv_busy = true
        TriggerClientEvent('qb-inventory:client:openInventory', source, QBPlayer.PlayerData.items)
        return
    end

    if type(identifier) ~= 'string' then print('Inventory tried to open an invalid identifier') return end

    local inventory = Inventories[identifier]
    if inventory and inventory.isOpen then
        TriggerClientEvent('QBCore:Notify', source, 'This inventory is currently in use', 'error')
        return
    end

    if not inventory then inventory = InitializeInventory(identifier, data) end
    inventory.maxweight = (data and data.maxweight) or (inventory and inventory.maxweight) or Config.StashSize.maxweight
    inventory.slots = (data and data.slots) or (inventory and inventory.slots) or Config.StashSize.slots
    inventory.label = (data and data.label) or (inventory and inventory.label) or identifier
    inventory.isOpen = source

    local formattedInventory = { name = identifier, label = inventory.label, maxweight = inventory.maxweight, slots = inventory.slots, inventory = inventory.items }
    TriggerClientEvent('qb-inventory:client:sendServerTime', source, os.time())
    TriggerClientEvent('qb-inventory:client:openInventory', source, QBPlayer.PlayerData.items, formattedInventory)
end
exports('OpenInventory', OpenInventory)

function CreateInventory(identifier, data)
    if Inventories[identifier] then return end
    if not identifier then return end
    Inventories[identifier] = InitializeInventory(identifier, data)
end
exports('CreateInventory', CreateInventory)

function GetInventory(identifier)
    return Inventories[identifier]
end
exports('GetInventory', GetInventory)

function RemoveInventory(identifier)
    if Inventories[identifier] then
        Inventories[identifier] = nil
    end
end
exports('RemoveInventory', RemoveInventory)

function AddItem(identifier, item, amount, slot, info, reason)
    local itemInfo = QBCore.Shared.Items[item:lower()]
    if not itemInfo then
        print('AddItem: Invalid item "' .. tostring(item) .. '"')
        return false
    end

    local player = QBCore.Functions.GetPlayer(identifier)
    local inventory, inventoryWeight, inventorySlots
    local inventoryType = nil

    if player then
        inventory, inventoryWeight, inventorySlots = player.PlayerData.items, Config.MaxWeight, Config.MaxSlots
        inventoryType = 'player'
    elseif Inventories[identifier] then
        inventory, inventoryWeight, inventorySlots = Inventories[identifier].items, Inventories[identifier].maxweight, Inventories[identifier].slots
        inventoryType = 'stash'
    elseif Drops[identifier] then
        inventory, inventoryWeight, inventorySlots = Drops[identifier].items, Drops[identifier].maxweight, Drops[identifier].slots
        inventoryType = 'drop'
    else
        print('AddItem: Inventory not found for ' .. tostring(identifier))
        return false
    end

    if GetTotalWeight(inventory) + (itemInfo.weight * amount) > inventoryWeight then
        return false
    end

    amount = tonumber(amount) or 1
    local updated = false

    if not itemInfo.unique then
        local targetSlot = slot
        if not targetSlot then
            for k, v in pairs(inventory) do
                if v.name == item then
                    local canStack = true
                    if v.info and v.info.expiryDate then
                        if not info or not info.expiryDate or info.expiryDate ~= v.info.expiryDate then
                            canStack = false
                        end
                    end
                    if canStack then
                        targetSlot = k
                        break
                    end
                end
            end
        end

        if targetSlot and inventory[targetSlot] and inventory[targetSlot].name == item then
            inventory[targetSlot].amount = inventory[targetSlot].amount + amount
            updated = true
            slot = targetSlot
        end
    end

    if not updated then
        slot = slot or GetFirstFreeSlot(inventory, inventorySlots)
        if not slot then
            return false
        end

        local newItemInfo = info or {}
        local currentTime = os.time()

        if itemInfo.decayrate and not newItemInfo.expiryDate then
            newItemInfo.creationDate = currentTime
            newItemInfo.expiryDate = currentTime + itemInfo.decayrate
        elseif not newItemInfo.creationDate then
            newItemInfo.creationDate = currentTime
        end

        inventory[slot] = {
            name = item,
            amount = amount,
            info = newItemInfo,
            label = itemInfo.label,
            description = itemInfo.description or '',
            weight = itemInfo.weight,
            type = itemInfo.type,
            unique = itemInfo.unique,
            useable = itemInfo.useable,
            image = itemInfo.image,
            shouldClose = itemInfo.shouldClose,
            slot = slot,
            combinable = itemInfo.combinable
        }

        if itemInfo.type == 'weapon' then
            if not inventory[slot].info.serie then
                inventory[slot].info.serie = tostring(QBCore.Shared.RandomInt(2) .. QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(1) .. QBCore.Shared.RandomStr(2) .. QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(4))
            end
            if not inventory[slot].info.quality then
                inventory[slot].info.quality = 100
            end
        end
    end
    if inventoryType == 'player' then
        player.Functions.SetPlayerData('items', inventory)
        ScheduleSave(identifier)
        if item == 'cash' and Config.CashAsItem then
            player.Functions.SetMoney('cash', GetItemCount(identifier, 'cash') or 0)
        end
        TriggerClientEvent('qb-inventory:client:ItemBox', identifier, itemInfo, 'add', amount)
        TriggerClientEvent('qb-inventory:client:updateInventory', identifier)
    elseif inventoryType == 'stash' then
        Inventories[identifier].items = inventory
    elseif inventoryType == 'drop' then
        Drops[identifier].items = inventory
    end

    local invName = player and GetPlayerName(identifier) .. ' (' .. identifier .. ')' or identifier
    local addReason = reason or 'No reason specified'
    local resourceName = GetInvokingResource() or 'qb-inventory'
    TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'Item Added', 'green', '**Inventory:** ' .. invName .. ' (Slot: ' .. tostring(slot) .. ')\n' .. '**Item:** ' .. item .. '\n' .. '**Amount:** ' .. amount .. '\n' .. '**Reason:** ' .. addReason .. '\n' .. '**Resource:** ' .. resourceName)
    
    return true
end
exports('AddItem', AddItem)

function RemoveItem(identifier, item, amount, slot, reason)
    local player = QBCore.Functions.GetPlayer(identifier)
    local inventory, inventoryType

    if player then
        inventory, inventoryType = player.PlayerData.items, 'player'
    elseif Inventories[identifier] then
        inventory, inventoryType = Inventories[identifier].items, 'stash'
    elseif Drops[identifier] then
        inventory, inventoryType = Drops[identifier].items, 'drop'
    else
        print('RemoveItem: Inventory not found for ' .. tostring(identifier))
        return false
    end

    amount = tonumber(amount)
    if not amount or amount <= 0 then return false end
    local itemName = item:lower()
    local itemInfo = QBCore.Shared.Items[itemName]
    if not itemInfo then return false end
    local currentAmount = 0
    for _, itemData in pairs(inventory) do
        if itemData and itemData.name == itemName then
            currentAmount = currentAmount + itemData.amount
        end
    end
    if currentAmount < amount then return false end

    local amountToRemove = amount

    if slot then
        local itemInSlot = inventory[slot]
        if itemInSlot and itemInSlot.name == itemName and itemInSlot.amount >= amountToRemove then
            itemInSlot.amount = itemInSlot.amount - amountToRemove
            if itemInSlot.amount <= 0 then inventory[slot] = nil end
            amountToRemove = 0
        else
            return false
        end
    else
        local slots = {}
        for k in pairs(inventory) do table.insert(slots, k) end
        table.sort(slots)

        for _, slotKey in ipairs(slots) do
            if amountToRemove <= 0 then break end
            local invItem = inventory[slotKey]
            if invItem and invItem.name == itemName then
                if invItem.amount > amountToRemove then
                    invItem.amount = invItem.amount - amountToRemove
                    amountToRemove = 0
                else
                    amountToRemove = amountToRemove - invItem.amount
                    inventory[slotKey] = nil
                end
            end
        end
    end

    if amountToRemove > 0 then return false end
    if inventoryType == 'player' then
        player.Functions.SetPlayerData('items', inventory)
        ScheduleSave(identifier)
        if itemName == 'cash' and Config.CashAsItem then
            player.Functions.SetMoney('cash', GetItemCount(identifier, 'cash') or 0)
        end
        TriggerClientEvent('qb-inventory:client:ItemBox', identifier, itemInfo, 'remove', amount)
        TriggerClientEvent('qb-inventory:client:updateInventory', identifier)
    elseif inventoryType == 'stash' then
        Inventories[identifier].items = inventory
    elseif inventoryType == 'drop' then
        Drops[identifier].items = inventory
    end

    local invName = player and GetPlayerName(identifier) .. ' (' .. identifier .. ')' or identifier
    local removeReason = reason or 'No reason specified'
    local resourceName = GetInvokingResource() or 'qb-inventory'
    TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'Item Removed', 'red', '**Inventory:** ' .. invName .. ' | **Item:** ' .. item .. ' | **Amount:** ' .. amount .. ' | **Reason:** ' .. removeReason .. ' | **Resource:** ' .. resourceName)
    
    return true
end
exports('RemoveItem', RemoveItem)

function GetInventory(identifier)
    return Inventories[identifier]
end

exports('GetInventory', GetInventory)