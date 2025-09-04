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

function AddCash(source, amount, reason)
    if not source or not amount then return false end
    local PlayerObject = QBCore.Functions.GetPlayer(source)
    if not PlayerObject then return false end
    
    reason = reason or 'unknown'

    if AddItem(source, 'cash', amount, nil, {}, 'money_as_item:add (' .. reason .. ')') then
        local currentCash = GetItemCount(source, 'cash')
        PlayerObject.Functions.SetMoney('cash', currentCash)
        
        TriggerClientEvent('qb-inventory:client:updateCash', source, currentCash)
        
        local itemInfo = QBCore.Shared.Items['cash']
        TriggerClientEvent('qb-inventory:client:ItemBox', source, itemInfo, 'add', amount)

        return true
    end
    return false
end
exports('AddCash', AddCash)

function RemoveCash(source, amount, reason)
    if not source or not amount then return false end
    local PlayerObject = QBCore.Functions.GetPlayer(source)
    if not PlayerObject then return false end
    
    reason = reason or 'unknown'

    local hasEnough = HasItem(source, 'cash', amount)
    if not hasEnough then return false end

    if RemoveItem(source, 'cash', amount, nil, 'money_as_item:remove (' .. reason .. ')') then
        local currentCash = GetItemCount(source, 'cash')
        PlayerObject.Functions.SetMoney('cash', currentCash)
        
        TriggerClientEvent('qb-inventory:client:updateCash', source, currentCash)
        
        local itemInfo = QBCore.Shared.Items['cash']
        TriggerClientEvent('qb-inventory:client:ItemBox', source, itemInfo, 'remove', amount)
        
        return true
    end
    return false
end
exports('RemoveCash', RemoveCash)

exports('SaveInventory', SaveInventory)

--- @param identifier string The identifier of the player or inventory.
--- @param items table The items to set in the inventory.
--- @param reason string The reason for setting the items.
function SetInventory(identifier, items, reason)
    local player = QBCore.Functions.GetPlayer(identifier)

    print('Setting inventory for ' .. identifier)

    if not player and not Inventories[identifier] and not Drops[identifier] then
        print('SetInventory: Inventory not found')
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
    TriggerEvent(
        'qb-log:server:CreateLog',
        'playerinventory',
        'Inventory Set',
        'blue',
        '**Inventory:** ' .. invName .. '\n' ..
        '**Items:** ' .. json.encode(items) .. '\n' ..
        '**Reason:** ' .. setReason .. '\n' ..
        '**Resource:** ' .. resourceName
    )
end

exports('SetInventory', SetInventory)

--- @param source number The player's server ID.
--- @param itemName string The name of the item.
--- @param key string The key to set the value for.
--- @param val any The value to set for the key.
--- @param slot number (optional) The slot number of the item. If not provided, it will search by name.
--- @return boolean|nil - Returns true if the value was set successfully, false otherwise.
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

--- @param items table The table containing the items.
--- @param itemName string The name of the item to search for.
--- @return table A table containing the slots where the item was found.
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

--- @param items table The table of items to search through.
--- @param itemName string The name of the item to search for.
--- @return number|nil - The slot number of the first matching item, or nil if no match is found.
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

--- @param source number The player's server ID.
--- @param slot number The slot number of the item.
--- @return table|nil - item data if found, or nil if not found.
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
        local amount = item.amount
        if type(amount) ~= 'number' then
            amount = 1
        end

        weight = weight + (item.weight * amount)
    end
    return tonumber(weight)
end

exports('GetTotalWeight', GetTotalWeight)

--- @param source number - The player's server ID.
--- @param item string - The name of the item to retrieve.
--- @return table|nil - item data if found, nil otherwise.
function GetItemByName(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    local items = Player.PlayerData.items
    local slot = GetFirstSlotByItem(items, tostring(item):lower())
    return items[slot]
end

exports('GetItemByName', GetItemByName)

--- @param source number The player's server ID.
--- @param item string The name of the item to search for.
--- @return table|nil - containing the items with the specified name.
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

--- @param identifier number|string The player's identifier or the identifier of an inventory or drop.
--- @return number, number - The total count of used slots and the total count of free slots. If no inventory is found, returns 0 and the maximum slots.
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
    if not inventory then return 0, maxSlots end
    local slotsUsed = 0
    for _, v in pairs(inventory) do
        if v then
            slotsUsed = slotsUsed + 1
        end
    end
    local slotsFree = maxSlots - slotsUsed
    return slotsUsed, slotsFree
end

exports('GetSlots', GetSlots)

--- @param source number The player's source ID.
--- @param items table|string The items to count. Can be either a table of item names or a single item name.
--- @return number|nil - The total count of the specified items.
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

--- @param identifier string The identifier of the player or inventory.
--- @param item string The item name.
--- @param amount number The amount of the item.
--- @return boolean - Returns true if the item can be added, false otherwise.
--- @return string|nil - Returns a string indicating the reason why the item cannot be added (e.g., 'weight' or 'slots'), or nil if it can be added.
function CanAddItem(identifier, item, amount)
    local Player = QBCore.Functions.GetPlayer(identifier)

    local itemData = QBCore.Shared.Items[item:lower()]
    if not itemData then return false end

    local inventory, items
    if Player then
        inventory = {
            maxweight = Config.MaxWeight,
            slots = Config.MaxSlots
        }
        items = Player.PlayerData.items
    elseif Inventories[identifier] then
        inventory = Inventories[identifier]
        items = Inventories[identifier].items
    end

    if not inventory then
        print('CanAddItem: Inventory not found')
        return false
    end

    local weight = itemData.weight * amount
    local totalWeight = GetTotalWeight(items) + weight
    if totalWeight > inventory.maxweight then
        return false, 'weight'
    end

    local slotsUsed, _ = GetSlots(identifier)

    if slotsUsed >= inventory.slots then
        for _, v in pairs(items) do
            if v.name == itemData.name then
                if itemData.unique then break end
                print(('CanAddItem: Player %s has no free slots for item %s, but has %d of it already'):format(identifier, itemData.name, v.amount))
                goto continue
            end
        end
        return false, 'slots'
    end

    ::continue::
    
    return true
end

exports('CanAddItem', CanAddItem)

--- @param source number The player's server ID.
--- @return number - Returns the free weight of the players inventory. Error will return 0
function GetFreeWeight(source)
    if not source then
        warn('Source was not passed into GetFreeWeight')
        return 0
    end
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return 0 end

    local totalWeight = GetTotalWeight(Player.PlayerData.items)
    local freeWeight = Config.MaxWeight - totalWeight
    return freeWeight
end

exports('GetFreeWeight', GetFreeWeight)

function ClearInventory(source, filterItems)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return end

    local playerItems = player.PlayerData.items
    local savedItemData = {}

    for slot, itemData in pairs(playerItems) do
        if itemData and itemData.name == 'cash' then
            savedItemData[slot] = itemData
        end
    end

    if filterItems then
        if type(filterItems) == 'string' then
            local item = GetItemByName(source, filterItems)
            if item and not savedItemData[item.slot] then 
                savedItemData[item.slot] = item 
            end
        elseif type(filterItems) == 'table' then
            for _, itemName in ipairs(filterItems) do
                local items = GetItemsByName(source, itemName)
                for _, item in ipairs(items) do
                    if item and not savedItemData[item.slot] then
                        savedItemData[item.slot] = item
                    end
                end
            end
        end
    end

    player.Functions.SetPlayerData('items', savedItemData)
    ScheduleSave(source)
    if not player.Offline then
        local logMessage = string.format('**%s (citizenid: %s | id: %s)** inventory cleared (cash preserved)', GetPlayerName(source), player.PlayerData.citizenid, source)
        TriggerEvent('qb-log-new:server:CreateLog', 'playerinventory', 'ClearInventory', 'red', logMessage)
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

--- @param source number The player's server ID.
--- @param items string|table The name of the item or a table of item names.
--- @param amount number (optional) The minimum amount required for each item.
--- @return boolean - Returns true if the player has the item(s) with the specified amount, false otherwise.
function HasItem(source, items, amount)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end

    if type(items) ~= 'table' then
        local itemName = items
        local requiredAmount = amount or 1
        local totalAmount = 0
        for _, itemData in pairs(Player.PlayerData.items) do
            if itemData and itemData.name == itemName then
                totalAmount = totalAmount + itemData.amount
            end
        end
        return totalAmount >= requiredAmount
    else
        for itemName, requiredAmount in pairs(items) do
            local totalAmount = 0
            for _, itemData in pairs(Player.PlayerData.items) do
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

--- @param source number - The player's server ID.
--- @param targetId number - The ID of the player whose inventory will be opened.
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

--- @param identifier string
function ClearStash(identifier)
    if not identifier then return end
    local inventory = Inventories[identifier]
    if not inventory then return end
    inventory.items = {}
    MySQL.prepare('UPDATE inventories SET items = ? WHERE identifier = ?', { json.encode(inventory.items), identifier })
end

exports('ClearStash', ClearStash)

--- @param shopData table The data of the shop to create.
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

--- @param source number The player's server ID.
--- @param name string The identifier of the inventory to open.
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
            local distance = #(playerCoords - shopDistance)
            if distance > 5.0 then return end
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

--- @param source number The player's server ID.
--- @param identifier string|nil The identifier of the inventory to open.
--- @param data table|nil Additional data for initializing the inventory.
function OpenInventory(source, identifier, data)
    if Player(source).state.inv_busy then return end
    local QBPlayer = QBCore.Functions.GetPlayer(source)
    if not QBPlayer then return end

    if not identifier then
        Player(source).state.inv_busy = true
        TriggerClientEvent('qb-inventory:client:openInventory', source, QBPlayer.PlayerData.items)
        return
    end

    if type(identifier) ~= 'string' then
        print('Inventory tried to open an invalid identifier')
        return
    end

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

    local formattedInventory = {
        name = identifier,
        label = inventory.label,
        maxweight = inventory.maxweight,
        slots = inventory.slots,
        inventory = inventory.items
    }
    TriggerClientEvent('qb-inventory:client:sendServerTime', source, os.time())
    TriggerClientEvent('qb-inventory:client:openInventory', source, QBPlayer.PlayerData.items, formattedInventory)
end

exports('OpenInventory', OpenInventory)

--- @param identifier string The identifier of the inventory to create.
--- @param data table Additional data for initializing the inventory.
function CreateInventory(identifier, data)
    if Inventories[identifier] then return end
    if not identifier then return end
    Inventories[identifier] = InitializeInventory(identifier, data)
end

exports('CreateInventory', CreateInventory)

--- @param identifier string The identifier of the inventory to retrieve.
--- @return table|nil - The inventory object if found, nil otherwise.
function GetInventory(identifier)
    return Inventories[identifier]
end

exports('GetInventory', GetInventory)

--- @param identifier string The identifier of the inventory to remove.
function RemoveInventory(identifier)
    if Inventories[identifier] then
        Inventories[identifier] = nil
    end
end

exports('RemoveInventory', RemoveInventory)

--- @param identifier string The identifier of the player or inventory.
--- @param item string The name of the item to add.
--- @param amount number The amount of the item to add.
--- @param slot number (optional) The slot to add the item to. If not provided, it will find the first available slot.
--- @param info table (optional) Additional information about the item.
--- @param reason string (optional) The reason for adding the item.
--- @return boolean Returns true if the item was successfully added, false otherwise.
function AddItem(identifier, item, amount, slot, info, reason)
    local itemInfo = QBCore.Shared.Items[item:lower()]
    if not itemInfo then
        print('AddItem: Invalid item')
        return false
    end
    local inventory, inventoryWeight, inventorySlots
    local player = QBCore.Functions.GetPlayer(identifier)

    if player then
        inventory = player.PlayerData.items
        inventoryWeight = Config.MaxWeight
        inventorySlots = Config.MaxSlots
    elseif Inventories[identifier] then
        inventory = Inventories[identifier].items
        inventoryWeight = Inventories[identifier].maxweight
        inventorySlots = Inventories[identifier].slots
    elseif Drops[identifier] then
        inventory = Drops[identifier].items
        inventoryWeight = Drops[identifier].maxweight
        inventorySlots = Drops[identifier].slots
    end

    if not inventory then
        print('AddItem: Inventory not found')
        return false
    end

    local totalWeight = GetTotalWeight(inventory)
    if totalWeight + (itemInfo.weight * amount) > inventoryWeight then
        print('AddItem: Not enough weight available')
        return false
    end

    amount = tonumber(amount) or 1
    local updated = false
    if not itemInfo.unique then
        local targetSlot = slot
        if not targetSlot then
            for k, v in pairs(inventory) do
                if v.name == item then
                    if not itemInfo.decayrate then
                        targetSlot = k
                        break
                    end
                end
            end
        end

        if targetSlot and inventory[targetSlot] and inventory[targetSlot].name == item then
            inventory[targetSlot].amount = inventory[targetSlot].amount + amount
            updated = true
        end
    end

    if not updated then
        slot = slot or GetFirstFreeSlot(inventory, inventorySlots)
        if not slot then
            print('AddItem: No free slot available')
            return false
        end
        local newItemInfo = info or {}
        local currentTime = os.time()

        if not newItemInfo.creationDate then
        newItemInfo.creationDate = currentTime
    end

        if itemInfo.decayrate and not newItemInfo.creationDate then
            newItemInfo.creationDate = currentTime
            newItemInfo.expiryDate = currentTime + itemInfo.decayrate
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

    if player then 
    player.Functions.SetPlayerData('items', inventory)
    ScheduleSave(identifier)
    end

    local invName = player and GetPlayerName(identifier) .. ' (' .. identifier .. ')' or identifier
    local addReason = reason or 'No reason specified'
    local resourceName = GetInvokingResource() or 'qb-inventory'
    TriggerEvent(
        'qb-log:server:CreateLog',
        'playerinventory',
        'Item Added',
        'green',
        '**Inventory:** ' .. invName .. ' (Slot: ' .. tostring(slot) .. ')\n' ..
        '**Item:** ' .. item .. '\n' ..
        '**Amount:** ' .. amount .. '\n' ..
        '**Reason:** ' .. addReason .. '\n' ..
        '**Resource:** ' .. resourceName
    )
    local p = QBCore.Functions.GetPlayer(identifier)
    if p and p.state and not p.state.inv_busy then
        TriggerClientEvent('qb-inventory:client:ItemBox', identifier, itemInfo, 'add', amount)
    end

     if player and item == 'cash' then
        local currentCash = GetItemCount(identifier, 'cash') or 0
        player.Functions.SetMoney('cash', currentCash)
        TriggerClientEvent('qb-inventory:client:updateInventory', identifier)
    end
    
    return true
end

exports('AddItem', AddItem)

--- @param identifier string - The identifier of the player.
--- @param item string - The name of the item to remove.
--- @param amount number - The amount of the item to remove.
--- @param slot number - (Optional) The specific slot to remove from. If nil, removes from any stack.
--- @param reason string - The reason for removing the item.
--- @return boolean - Returns true if the item was successfully removed, false otherwise.
function RemoveItem(identifier, item, amount, slot, reason)
    local player = QBCore.Functions.GetPlayer(identifier)
    local otherInventory = not player and (Inventories[identifier] or (Drops[identifier] and Drops[identifier]))

    if not player and not otherInventory then
        print('RemoveItem: Inventory not found for identifier: ' .. tostring(identifier))
        return false
    end

    amount = tonumber(amount)
    if not amount or amount <= 0 then return false end

    local itemName = item:lower()
    local itemInfo = QBCore.Shared.Items[itemName]
    if not itemInfo then return false end
    if otherInventory then
        local totalAmount = 0
        for _, itemData in pairs(otherInventory.items) do
            if itemData and itemData.name == itemName then
                totalAmount = totalAmount + itemData.amount
            end
        end
        if totalAmount < amount then return false end
    elseif player and not HasItem(identifier, itemName, amount) then
        return false
    end

    local inventory = player and player.PlayerData.items or otherInventory.items
    local amountToRemove = amount

    if slot then
        local itemInSlot = inventory[slot]
        if itemInSlot and itemInSlot.name == itemName and itemInSlot.amount >= amountToRemove then
            itemInSlot.amount = itemInSlot.amount - amountToRemove
            if itemInSlot.amount <= 0 then
                inventory[slot] = nil
            end
            amountToRemove = 0
        else
            return false
        end
    else
        local slots = {}
        for k in pairs(inventory) do
            table.insert(slots, k)
        end
        table.sort(slots)

        for _, slotKey in ipairs(slots) do
            if amountToRemove <= 0 then break end
            local invItem = inventory[slotKey]
            if invItem and invItem.name == itemName then
                if invItem.amount >= amountToRemove then
                    invItem.amount = invItem.amount - amountToRemove
                    if invItem.amount <= 0 then
                        inventory[slotKey] = nil
                    end
                    amountToRemove = 0
                else
                    amountToRemove = amountToRemove - invItem.amount
                    inventory[slotKey] = nil
                end
            end
        end
    end

    if amountToRemove > 0 then
        return false
    end

    if player then
        player.Functions.SetPlayerData('items', inventory)
        ScheduleSave(identifier)
    else
        otherInventory.items = inventory
    end

    local invName = player and GetPlayerName(identifier) .. ' (' .. identifier .. ')' or identifier
    local removeReason = reason or 'No reason specified'
    local resourceName = GetInvokingResource() or 'qb-inventory'
    TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'Item Removed', 'red', '**Inventory:** ' .. invName .. ' | **Item:** ' .. item .. ' | **Amount:** ' .. amount .. ' | **Reason:** ' .. removeReason .. ' | **Resource:** ' .. resourceName)

    local p = QBCore.Functions.GetPlayer(identifier)
    if p and p.state and not p.state.inv_busy then
        TriggerClientEvent('qb-inventory:client:ItemBox', identifier, itemInfo, 'remove', amount)
    end
    if player and itemName == 'cash' then
        local currentCash = GetItemCount(identifier, 'cash') or 0
        player.Functions.SetMoney('cash', currentCash)
        TriggerClientEvent('qb-inventory:client:updateInventory', identifier)
    end

    return true
end
exports('RemoveItem', RemoveItem)

function GetInventory(identifier)
    return Inventories[identifier]
end

exports('GetInventory', GetInventory)
