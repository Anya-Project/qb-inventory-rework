---------------------------
-- server/compat.lua
---------------------------

QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent('inventory:server:OpenInventory', function(name, data_or_targetid, slots)
    local src = source
    if not name then return end

    if name == 'shop' then
        local shopIdentifier = tostring(data_or_targetid)
        local shopData = slots

        if type(shopData) == 'table' and shopData.items then
            exports['qb-inventory']:CreateShop({
                name = shopIdentifier,
                label = shopData.label or shopIdentifier,
                items = shopData.items
            })
            
            exports['qb-inventory']:OpenShop(src, shopIdentifier)
        end
    elseif name == 'otherplayer' or name == 'player' then
        local targetId = tonumber(data_or_targetid)
        if not targetId then return end
        exports['qb-inventory']:OpenInventoryById(src, targetId)
    else
        local identifier
        local inventoryData
        if type(slots) == 'table' then
            identifier = data_or_targetid
            inventoryData = slots
            inventoryData.label = inventoryData.label or identifier
        else
            identifier = name
            inventoryData = {
                label = name,
                maxweight = data_or_targetid or Config.StashSize.maxweight,
                slots = slots or Config.StashSize.slots
            }
        end
        if identifier then
            exports['qb-inventory']:OpenInventory(src, identifier, inventoryData)
        end
    end
end)

RegisterNetEvent('QBCore:Server:AddItem', function(item, amount, slot, info)
    local src = source
    if not item or not amount then return end
    exports['qb-inventory']:AddItem(src, item, tonumber(amount), slot, info, 'legacy_event_compat')
end)

RegisterNetEvent('QBCore:Server:RemoveItem', function(item, amount, slot)
    local src = source
    if not item or not amount then return end
    exports['qb-inventory']:RemoveItem(src, item, tonumber(amount), slot, 'legacy_event_compat')
end)

QBCore.Functions.CreateCallback('QBCore:Server:HasItem', function(source, cb, item, amount)
    local hasItem = exports['qb-inventory']:HasItem(source, item, amount)
    cb(hasItem)
end)

print('^[2]QB-Inventory: ^7Legacy Compatibility Bridge (Smart Version) Loaded!^0')