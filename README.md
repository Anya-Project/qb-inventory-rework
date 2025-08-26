<!-- Banner / Cover Image -->
<p align="center">
    <img width="300" src="https://i.imgur.com/JaOJmKS.png" />
---

## 🌐 Connect with Us

<p align="center">
  <a href="https://discord.gg/HMMYNPEXGY"><img src="https://img.shields.io/badge/Discord-%237289DA.svg?style=for-the-badge&logo=discord&logoColor=white"/></a>
  <a href="https://www.youtube.com/@apcodeid"><img src="https://img.shields.io/badge/YouTube-%23FF0000.svg?style=for-the-badge&logo=YouTube&logoColor=white"/></a>
</p>

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/H2H51HUE4X)

## [QB INVENTORY REWORK] a modern, feature-rich, and optimized inventory system for the QBCore Framework.

![Inventory Showcase](https://i.imgur.com/gCWzI8h.png)
![Inventory Showcase](https://i.imgur.com/NUgPvCy.png)

---

## 📜 Description

QB Inventory Rework is a complete replacement for the default QBCore inventory, designed to provide a more immersive and functional experience for players.

---

## ✨ Core Features

- Cash as an item
- New give system
- Decay system for food & drinks
- Weapon attachment panel
- New 2-panel UI layout
- Toggle blur effect
- Code modifications for optimization & security

---

[**Join the Official AP Code Discord**](https://discord.gg/HMMYNPEXGY)

## 📦 Dependencies

Ensure you have the following resources installed and running before installing qb-Inventory rework :

- [**qb-core**](https://github.com/qbcore-framework/qb-core)

---

## 🛠️ Installation

Follow these steps **very carefully** to ensure a smooth installation.

### Step 1: Download & Place the Resource

1.  Download this resource's files
2.  Rename qb-inventory-rework to qb-inventory
3.  delete your old inventory and replace with `qb-inventory` rework

### Step 2: Modify `qb-core`

**🚨 IMPORTANT: Always create a backup of any file you are about to edit!**

You need to edit the `qb-core/server/player.lua` file to integrate the money-as-an-item system.

#### A. Replace Money Management Functions

Open `qb-core/server/player.lua` and find the following functions:

- `self.Functions.AddMoney`
- `self.Functions.RemoveMoney`
- `self.Functions.SetMoney`
- `self.Functions.GetMoney`

Delete all four of these functions entirely and replace them with the code block below:

<details>
<summary>Click to view the replacement code for money functions</summary>

```lua
------------------------------------------- EDITED BY AP_CODE --------------------------------------------------
function self.Functions.AddMoney(moneytype, amount, reason)
    reason = reason or 'unknown'
    moneytype = moneytype:lower()
    amount = tonumber(amount)
    if amount < 0 then return end
    if not self.PlayerData.money[moneytype] then return false end
    if moneytype == 'cash' then
        if exports['ap-inventory']:AddCash(self.PlayerData.source, amount) then
            if not self.Offline then
                if amount > 100000 then
                    TriggerEvent('qb-log:server:CreateLog', 'playermoney', 'AddMoney (as item)', 'lightgreen', '**' .. GetPlayerName(self.PlayerData.source) .. ' (citizenid: ' .. self.PlayerData.citizenid .. ' | id: ' .. self.PlayerData.source .. ')** $' .. amount .. ' (cash) added, reason: ' .. reason, true)
                else
                    TriggerEvent('qb-log:server:CreateLog', 'playermoney', 'AddMoney (as item)', 'lightgreen', '**' .. GetPlayerName(self.PlayerData.source) .. ' (citizenid: ' .. self.PlayerData.citizenid .. ' | id: ' .. self.PlayerData.source .. ')** $' .. amount .. ' (cash) added, reason: ' .. reason)
                end
                TriggerClientEvent('QBCore:Client:OnMoneyChange', self.PlayerData.source, moneytype, amount, 'add', reason)
                TriggerEvent('QBCore:Server:OnMoneyChange', self.PlayerData.source, moneytype, amount, 'add', reason)
            end
            return true
        else
            return false
        end
    end
    self.PlayerData.money[moneytype] = self.PlayerData.money[moneytype] + amount
    if not self.Offline then
        self.Functions.UpdatePlayerData()
        if amount > 100000 then
            TriggerEvent('qb-log:server:CreateLog', 'playermoney', 'AddMoney', 'lightgreen', '**' .. GetPlayerName(self.PlayerData.source) .. ' (citizenid: ' .. self.PlayerData.citizenid .. ' | id: ' .. self.PlayerData.source .. ')** $' .. amount .. ' (' .. moneytype .. ') added, new ' .. moneytype .. ' balance: ' .. self.PlayerData.money[moneytype] .. ' reason: ' .. reason, true)
        else
            TriggerEvent('qb-log:server:CreateLog', 'playermoney', 'AddMoney', 'lightgreen', '**' .. GetPlayerName(self.PlayerData.source) .. ' (citizenid: ' .. self.PlayerData.citizenid .. ' | id: ' .. self.PlayerData.source .. ')** $' .. amount .. ' (' .. moneytype .. ') added, new ' .. moneytype .. ' balance: ' .. self.PlayerData.money[moneytype] .. ' reason: ' .. reason)
        end
        TriggerClientEvent('hud:client:OnMoneyChange', self.PlayerData.source, moneytype, amount, false)
        TriggerClientEvent('QBCore:Client:OnMoneyChange', self.PlayerData.source, moneytype, amount, 'add', reason)
        TriggerEvent('QBCore:Server:OnMoneyChange', self.PlayerData.source, moneytype, amount, 'add', reason)
    end
    return true
end

function self.Functions.RemoveMoney(moneytype, amount, reason)
    reason = reason or 'unknown'
    moneytype = moneytype:lower()
    amount = tonumber(amount)
    if amount < 0 then return end
    if not self.PlayerData.money[moneytype] then return false end
    if moneytype == 'cash' then
        if exports['ap-inventory']:RemoveCash(self.PlayerData.source, amount, reason) then
            if not self.Offline then
                if amount > 100000 then
                    TriggerEvent('qb-log:server:CreateLog', 'playermoney', 'RemoveMoney (as item)', 'red', '**' .. GetPlayerName(self.PlayerData.source) .. ' (citizenid: ' .. self.PlayerData.citizenid .. ' | id: ' .. self.PlayerData.source .. ')** $' .. amount .. ' (cash) removed, reason: ' .. reason, true)
                else
                    TriggerEvent('qb-log:server:CreateLog', 'playermoney', 'RemoveMoney (as item)', 'red', '**' .. GetPlayerName(self.PlayerData.source) .. ' (citizenid: ' .. self.PlayerData.citizenid .. ' | id: ' .. self.PlayerData.source .. ')** $' .. amount .. ' (cash) removed, reason: ' .. reason)
                end
                TriggerClientEvent('QBCore:Client:OnMoneyChange', self.PlayerData.source, moneytype, amount, 'remove', reason)
                TriggerEvent('QBCore:Server:OnMoneyChange', self.PlayerData.source, moneytype, amount, 'remove', reason)
            end
            return true
        else
            return false
        end
    end
    for _, mtype in pairs(QBCore.Config.Money.DontAllowMinus) do
        if mtype == moneytype then
            if (self.PlayerData.money[moneytype] - amount) < 0 then
                return false
            end
        end
    end
    if self.PlayerData.money[moneytype] - amount < QBCore.Config.Money.MinusLimit then
        return false
    end
    self.PlayerData.money[moneytype] = self.PlayerData.money[moneytype] - amount
    if not self.Offline then
        self.Functions.UpdatePlayerData()
        if amount > 100000 then
            TriggerEvent('qb-log:server:CreateLog', 'playermoney', 'RemoveMoney', 'red', '**' .. GetPlayerName(self.PlayerData.source) .. ' (citizenid: ' .. self.PlayerData.citizenid .. ' | id: ' .. self.PlayerData.source .. ')** $' .. amount .. ' (' .. moneytype .. ') removed, new ' .. moneytype .. ' balance: ' .. self.PlayerData.money[moneytype] .. ' reason: ' .. reason, true)
        else
            TriggerEvent('qb-log:server:CreateLog', 'playermoney', 'RemoveMoney', 'red', '**' .. GetPlayerName(self.PlayerData.source) .. ' (citizenid: ' .. self.PlayerData.citizenid .. ' | id: ' .. self.PlayerData.source .. ')** $' .. amount .. ' (' .. moneytype .. ') removed, new ' .. moneytype .. ' balance: ' .. self.PlayerData.money[moneytype] .. ' reason: ' .. reason)
        end
        TriggerClientEvent('hud:client:OnMoneyChange', self.PlayerData.source, moneytype, amount, true)
        if moneytype == 'bank' then
            TriggerClientEvent('qb-phone:client:RemoveBankMoney', self.PlayerData.source, amount)
        end
        TriggerClientEvent('QBCore:Client:OnMoneyChange', self.PlayerData.source, moneytype, amount, 'remove', reason)
        TriggerEvent('QBCore:Server:OnMoneyChange', self.PlayerData.source, moneytype, amount, 'remove', reason)
    end
    return true
end

function self.Functions.SetMoney(moneytype, amount, reason)
    reason = reason or 'unknown'
    moneytype = moneytype:lower()
    amount = tonumber(amount)
    if amount < 0 then return false end
    if not self.PlayerData.money[moneytype] then return false end
    if moneytype == 'cash' then
        local currentCash = exports['ap-inventory']:GetItemCount(self.PlayerData.source, 'cash') or 0
        local difference = amount - currentCash
        local success = false
        if difference > 0 then
            success = exports['ap-inventory']:AddItem(self.PlayerData.source, 'cash', difference, nil, {}, 'setmoney_command')
        elseif difference < 0 then
            success = exports['ap-inventory']:RemoveItem(self.PlayerData.source, 'cash', math.abs(difference), nil, 'setmoney_command')
        else
            success = true
        end
        if success then
            local newTotalCash = exports['ap-inventory']:GetItemCount(self.PlayerData.source, 'cash') or 0
            self.PlayerData.money.cash = newTotalCash
            if not self.Offline then
                TriggerEvent('qb-log:server:CreateLog', 'playermoney', 'SetMoney (as item)', 'green', '**' .. GetPlayerName(self.PlayerData.source) .. ' (citizenid: ' .. self.PlayerData.citizenid .. ' | id: ' .. self.PlayerData.source .. ')** cash set to $' .. amount .. ', reason: ' .. reason)
                TriggerClientEvent('QBCore:Client:OnMoneyChange', self.PlayerData.source, moneytype, amount, 'set', reason)
                TriggerEvent('QBCore:Server:OnMoneyChange', self.PlayerData.source, moneytype, amount, 'set', reason)
                TriggerClientEvent('qb-inventory:client:updateCash', self.PlayerData.source, newTotalCash)
            end
        end
        return success
    end
    local difference = amount - self.PlayerData.money[moneytype]
    self.PlayerData.money[moneytype] = amount
    if not self.Offline then
        self.Functions.UpdatePlayerData()
        TriggerEvent('qb-log:server:CreateLog', 'playermoney', 'SetMoney', 'green', '**' .. GetPlayerName(self.PlayerData.source) .. ' (citizenid: ' .. self.PlayerData.citizenid .. ' | id: ' .. self.PlayerData.source .. ')** $' .. amount .. ' (' .. moneytype .. ') set, new ' .. moneytype .. ' balance: ' .. self.PlayerData.money[moneytype] .. ' reason: ' .. reason)
        TriggerClientEvent('hud:client:OnMoneyChange', self.PlayerData.source, moneytype, math.abs(difference), difference < 0)
        TriggerClientEvent('QBCore:Client:OnMoneyChange', self.PlayerData.source, moneytype, amount, 'set', reason)
        TriggerEvent('QBCore:Server:OnMoneyChange', self.PlayerData.source, moneytype, amount, 'set', reason)
    end
    return true
end

function self.Functions.GetMoney(moneytype)
    if not moneytype then return false end
    moneytype = moneytype:lower()
    if moneytype == 'cash' then
        if GetResourceState('ap-inventory') ~= 'missing' then
            local cashCount = exports['ap-inventory']:GetItemCount(self.PlayerData.source, 'cash') or 0
            if self.PlayerData.money.cash ~= cashCount then
                self.PlayerData.money.cash = cashCount
            end
            return cashCount
        else
            return self.PlayerData.money[moneytype]
        end
    end
    return self.PlayerData.money[moneytype]
end
------------------------------------------- EDITED BY AP_CODE --------------------------------------------------
```

</details>

#### B. Replace the `CheckPlayerData` Function

Still in `qb-core/server/player.lua`, find the function `QBCore.Player.CheckPlayerData`. Delete this function and replace it with the code block below. This change ensures the player's inventory is loaded correctly when they join the server.

<details>
<summary>Click to view the replacement code for CheckPlayerData</summary>

```lua
function QBCore.Player.CheckPlayerData(source, PlayerData)
    PlayerData = PlayerData or {}
    local Offline = not source
    if source then
        PlayerData.source = source
        PlayerData.license = PlayerData.license or QBCore.Functions.GetIdentifier(source, 'license')
        PlayerData.name = GetPlayerName(source)
    end
    local validatedJob = false
    if PlayerData.job and PlayerData.job.name ~= nil and PlayerData.job.grade and PlayerData.job.grade.level ~= nil then
        local jobInfo = QBCore.Shared.Jobs[PlayerData.job.name]
        if jobInfo then
            local jobGradeInfo = jobInfo.grades[tostring(PlayerData.job.grade.level)]
            if jobGradeInfo then
                PlayerData.job.label = jobInfo.label
                PlayerData.job.grade.name = jobGradeInfo.name
                PlayerData.job.payment = jobGradeInfo.payment
                PlayerData.job.grade.isboss = jobGradeInfo.isboss or false
                PlayerData.job.isboss = jobGradeInfo.isboss or false
                validatedJob = true
            end
        end
    end
    if validatedJob == false then
        PlayerData.job = nil
    end
    local validatedGang = false
    if PlayerData.gang and PlayerData.gang.name ~= nil and PlayerData.gang.grade and PlayerData.gang.grade.level ~= nil then
        local gangInfo = QBCore.Shared.Gangs[PlayerData.gang.name]
        if gangInfo then
            local gangGradeInfo = gangInfo.grades[tostring(PlayerData.gang.grade.level)]
            if gangGradeInfo then
                PlayerData.gang.label = gangInfo.label
                PlayerData.gang.grade.name = gangGradeInfo.name
                PlayerData.gang.payment = gangGradeInfo.payment
                PlayerData.gang.grade.isboss = gangGradeInfo.isboss or false
                PlayerData.gang.isboss = gangGradeInfo.isboss or false
                validatedGang = true
            end
        end
    end
    if validatedGang == false then
        PlayerData.gang = nil
    end
    applyDefaults(PlayerData, QBCore.Config.Player.PlayerDefaults)
    ------------------------------------------- EDITED BY AP_CODE --------------------------------------------------
    if GetResourceState('ap-inventory') ~= 'missing' then
        PlayerData.items = exports['ap-inventory']:LoadInventory(PlayerData.source, PlayerData.citizenid)
    end
    if PlayerData.items then
        local cashInInventory = 0
        for _, item in pairs(PlayerData.items) do
            if item and item.name == 'cash' then
                cashInInventory = cashInInventory + item.amount
            end
        end
        PlayerData.money.cash = cashInInventory
    end
    ------------------------------------------- EDITED BY AP_CODE --------------------------------------------------
    return QBCore.Player.CreatePlayer(PlayerData, Offline)
end
```

</details>

### Step 3: Add Cash Item to `qb-core/shared/items.lua`

<details>
<summary>Click to view the replacement code for CheckPlayerData</summary>
  
```lua
['cash'] = {
    name = 'cash',
    label = 'Cash',
    weight = 0,
    type = 'item',
    image = 'cash.png',
    unique = false,
    useable = false,
    shouldClose = false,
    description = 'Don\'t spend it all in one place.'
},
```
</details>

If you encounter any issues, require assistance, or wish to suggest new features, please join our official Discord server. We're here to help!

[**Join the Official AP Code Discord**](https://discord.gg/HMMYNPEXGY)

## ⚙️ Configuration

All major configuration options can be found in the `config.lua` file. You can adjust:

- The default keybind to open the inventory.
- Maximum weight and slot counts.
- Storage sizes for trunks, gloveboxes, and drops.
- Items sold in Vending Machines.
- And much more.

---

## 🆘 Support

## Special thanks to the QBCore community for their support and inspiration.
