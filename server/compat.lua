--server/compat.lua

QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent('inventory:server:OpenInventory', function(name, data_or_targetid, slots)
    local src = source
    if not name then return end
    if name == 'otherplayer' or name == 'player' then
        local targetId = tonumber(data_or_targetid)
        if not targetId then return end
     --   print(('[QB-INVENTORY-COMPAT] Accepting legacy event "OpenInventory" for player #%s. Opening via export OpenInventoryById...'):format(targetId))
        exports['qb-inventory']:OpenInventoryById(src, targetId)
    else
        local inventoryData = {
            label = name,
            maxweight = data_or_targetid or Config.StashSize.maxweight,
            slots = slots or Config.StashSize.slots
        }
   --     print(('[QB-INVENTORY-COMPAT] Accepting legacy event "OpenInventory" for stash: %s. Opening via export OpenInventory...'):format(name))
        exports['qb-inventory']:OpenInventory(src, name, inventoryData)
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

print('^[2]QB-Inventory: ^7Legacy Compatibility Bridge Loaded!^0')