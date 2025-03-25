﻿local GM = GM or GAMEMODE
lia.allowedHoldableClasses = {
    ["lia_item"] = true,
    ["lia_money"] = true,
    ["prop_physics"] = true,
    ["prop_physics_override"] = true,
    ["prop_physics_multiplayer"] = true,
    ["prop_ragdoll"] = true
}

function GM:CharPreSave(character)
    local client = character:getPlayer()
    if not character:getInv() then return end
    for _, v in pairs(character:getInv():getItems()) do
        if v.OnSave then v:call("OnSave", client) end
    end

    if IsValid(client) then
        local ammoTable = {}
        for _, ammoType in pairs(game.GetAmmoTypes()) do
            if ammoType then
                local ammoCount = client:GetAmmoCount(ammoType)
                if isnumber(ammoCount) and ammoCount > 0 then ammoTable[ammoType] = ammoCount end
            end
        end

        character:setData("ammo", ammoTable)
    end
end

function GM:PlayerLoadedChar(client, character)
    local timeStamp = os.date("%Y-%m-%d %H:%M:%S", os.time())
    lia.db.updateTable({
        _lastJoinTime = timeStamp
    }, nil, "characters", "_id = " .. character:getID())

    client:removeRagdoll()
    character:setData("loginTime", os.time())
    hook.Run("PlayerLoadout", client)
    local ammoTable = character:getData("ammo", {})
    if table.IsEmpty(ammoTable) then return end
    timer.Simple(0.25, function()
        if not IsValid(ammoTable) then return end
        for ammoType, ammoCount in pairs(ammoTable) do
            if IsValid(ammoCount) or IsValid(ammoCount) then client:GiveAmmo(ammoCount, ammoType, true) end
        end

        character:setData("ammo", nil)
    end)
end

function GM:CharLoaded(id)
    local character = lia.char.loaded[id]
    if character then
        local client = character:getPlayer()
        if IsValid(client) then
            local uniqueID = "liaSaveChar" .. client:SteamID64()
            timer.Create(uniqueID, lia.config.get("CharacterDataSaveInterval"), 0, function()
                if IsValid(client) and client:getChar() then
                    client:getChar():save()
                else
                    timer.Remove(uniqueID)
                end
            end)
        end
    end
end

function GM:PrePlayerLoadedChar(client)
    client:SetBodyGroups("000000000")
    client:SetSkin(0)
    client:ExitVehicle()
    client:Freeze(false)
end

function GM:OnPickupMoney(client, moneyEntity)
    if moneyEntity and IsValid(moneyEntity) then
        local amount = moneyEntity:getAmount()
        client:notifyLocalized("moneyTaken", lia.currency.get(amount))
        lia.log.add(client, "moneyPickedUp", amount)
    end
end

function GM:CanItemBeTransfered(item, curInv, inventory)
    if item.isBag and curInv ~= inventory and item.getInv and item:getInv() and table.Count(item:getInv():getItems()) > 0 then
        local character = lia.char.loaded[curInv.client]
        character:getPlayer():notifyError("You can't transfer a backpack that has items inside of it.")
        return false
    end

    if item.OnCanBeTransfered then
        local itemHook = item:OnCanBeTransfered(curInv, inventory)
        return itemHook ~= false
    end
end

function GM:CanPlayerInteractItem(client, action, item)
    action = string.lower(action)
    if not client:Alive() then return false, "You can't use items while dead" end
    if client:getLocalVar("ragdoll", false) then return false, "You can't use items while ragdolled." end
    if action == "drop" then
        if hook.Run("CanPlayerDropItem", client, item) ~= false then
            if not client.dropDelay then
                client.dropDelay = true
                timer.Create("DropDelay." .. client:SteamID64(), lia.config.get("DropDelay"), 1, function() if IsValid(client) then client.dropDelay = nil end end)
                return true
            else
                client:notifyWarning("You need to wait before dropping something again!")
                return false
            end
        else
            return false
        end
    end

    if action == "take" then
        if hook.Run("CanPlayerTakeItem", client, item) ~= false then
            if not client.takeDelay then
                client.takeDelay = true
                timer.Create("TakeDelay." .. client:SteamID64(), lia.config.get("TakeDelay"), 1, function() if IsValid(client) then client.takeDelay = nil end end)
                return true
            else
                client:notifyWarning("You need to wait before picking something up again!")
                return false
            end
        else
            return false
        end
    end

    if action == "equip" then
        if hook.Run("CanPlayerEquipItem", client, item) ~= false then
            if not client.equipDelay then
                client.equipDelay = true
                timer.Create("EquipDelay." .. client:SteamID64(), lia.config.get("EquipDelay"), 1, function() if IsValid(client) then client.equipDelay = nil end end)
                return true
            else
                client:notifyWarning("You need to wait before equipping something again!")
                return false
            end
        else
            return false
        end
    end

    if action == "unequip" then
        if hook.Run("CanPlayerUnequipItem", client, item) ~= false then
            if not client.unequipDelay then
                client.unequipDelay = true
                timer.Create("UnequipDelay." .. client:SteamID64(), lia.config.get("UnequipDelay"), 1, function() if IsValid(client) then client.unequipDelay = nil end end)
                return true
            else
                client:notifyWarning("You need to wait before unequipping something again!")
                return false
            end
        else
            return false
        end
    end
end

function GM:CanPlayerEquipItem(client, item)
    local inventory = lia.inventory.instances[item.invID]
    if client.equipDelay ~= nil then
        client:notifyWarning("You need to wait before equipping something again!")
        return false
    elseif inventory and (inventory.isBag or inventory.isExternalInventory) then
        client:notifyLocalized("forbiddenActionStorage")
        return false
    end
end

function GM:CanPlayerTakeItem(client, item)
    local inventory = lia.inventory.instances[item.invID]
    if client.takeDelay ~= nil then
        client:notifyWarning("You need to wait before picking something up again!")
        return false
    elseif inventory and (inventory.isBag or inventory.isExternalInventory) then
        client:notifyLocalized("forbiddenActionStorage")
        return false
    elseif IsValid(item.entity) then
        local character = client:getChar()
        if item.entity.SteamID64 == client:SteamID64() and item.entity.liaCharID ~= character:getID() then
            client:notifyLocalized("playerCharBelonging")
            return false
        end
    end
end

function GM:CanPlayerDropItem(client, item)
    local inventory = lia.inventory.instances[item.invID]
    if client.dropDelay ~= nil then
        client:notifyWarning("You need to wait before dropping something again!")
        return false
    elseif item.isBag and item:getInv() then
        local items = item:getInv():getItems()
        for _, otheritem in pairs(items) do
            if not otheritem.ignoreEquipCheck and otheritem:getData("equip", false) then
                client:notifyLocalized("cantDropBagHasEquipped")
                return false
            end
        end
    elseif inventory and (inventory.isBag or inventory.isExternalInventory) then
        client:notifyLocalized("forbiddenActionStorage")
        return false
    end
end

function GM:PlayerSay(client, message)
    local logTypeMap = {
        ooc = "chatOOC",
        looc = "chatLOOC"
    }

    local chatType, message, anonymous = lia.chat.parse(client, message, true)
    if chatType == "ic" and lia.command.parse(client, message) then return "" end
    if utf8.len(message) > lia.config.get("MaxChatLength") then
        client:notifyWarning("Your message is too long and has not been sent.")
        return ""
    end

    local logType = logTypeMap[chatType] or "chat"
    lia.chat.send(client, chatType, message, anonymous)
    if logType == "chat" then
        lia.log.add(client, logType, chatType and chatType:upper() or "??", message)
    else
        lia.log.add(client, logType, message)
    end

    hook.Run("PostPlayerSay", client, message, chatType, anonymous)
    return ""
end

function GM:CanPlayerHoldObject(_, entity)
    if lia.allowedHoldableClasses[entity:GetClass()] then return true end
end

function GM:EntityTakeDamage(entity, dmgInfo)
    if entity:IsPlayer() and entity:isStaffOnDuty() and lia.config.get("StaffHasGodMode", true) then
        return true
    end

    if IsValid(entity.liaPlayer) then
        if dmgInfo:IsDamageType(DMG_CRUSH) then
            if (entity.liaFallGrace or 0) < CurTime() then
                if dmgInfo:GetDamage() <= 10 then dmgInfo:SetDamage(0) end
                entity.liaFallGrace = CurTime() + 0.5
            else
                return
            end
        end

        entity.liaPlayer:TakeDamageInfo(dmgInfo)
    end
end

function GM:KeyPress(client, key)
    if key == IN_JUMP then
        local traceStart = client:GetShootPos() + Vector(0, 0, 15)
        local traceEndHi = traceStart + client:GetAimVector() * 30
        local traceEndLo = traceStart + client:GetAimVector() * 30
        local trHi = util.TraceLine({
            start = traceStart,
            endpos = traceEndHi,
            filter = client
        })

        local trLo = util.TraceLine({
            start = client:GetShootPos(),
            endpos = traceEndLo,
            filter = client
        })

        if trLo.Hit and not trHi.Hit then
            local dist = math.abs(trHi.HitPos.z - client:GetPos().z)
            client:SetVelocity(Vector(0, 0, 50 + dist * 3))
        end
    end
end

function GM:InitializedSchema()
    local persistString = GetConVar("sbox_persist"):GetString()
    if persistString == "" or string.StartWith(persistString, "lia_") then
        local newValue = "lia_" .. SCHEMA.folder
        game.ConsoleCommand("sbox_persist " .. newValue .. "\n")
    end
end

function GM:GetGameDescription()
    return istable(SCHEMA) and tostring(SCHEMA.name) or "A Lilia Gamemode"
end

function GM:PostPlayerLoadout(client)
    local character = client:getChar()
    if not character then return end

    client:Give("lia_hands")
    client:SetupHands()
end

function GM:ShouldSpawnClientRagdoll(client)
    if client:IsBot() then
        client:Spawn()
        return false
    end
end

function GM:DoPlayerDeath(client, attacker)
    client:AddDeaths(1)
    if hook.Run("ShouldSpawnClientRagdoll", client) ~= false then client:createRagdoll(false, true) end
    if IsValid(attacker) and attacker:IsPlayer() then
        if client == attacker then
            attacker:AddFrags(-1)
        else
            attacker:AddFrags(1)
        end
    end

    client:SetDSP(31)
end

function GM:PlayerDeath(client)
    local character = client:getChar()
    if not character then return end
    local inventory = character:getInv()
    if inventory then
        local items = inventory:getItems()
        for _, v in pairs(items) do
            if v.isWeapon and v:getData("equip") then v:setData("ammo", nil) end
        end
    end
end

function GM:PlayerSpawn(client)
    client:SetNoDraw(false)
    client:UnLock()
    client:SetNotSolid(false)
    client:stopAction()
    client:SetDSP(1)
    client:removeRagdoll()
    hook.Run("PlayerLoadout", client)
end

function GM:PlayerDisconnected(client)
    client:saveLiliaData()
    local character = client:getChar()
    if character then
        hook.Run("OnCharDisconnect", client, character)
        character:save()
    end

    client:removeRagdoll()
    lia.char.cleanUpForPlayer(client)
    for _, entity in ents.Iterator() do
        if entity:GetCreator() == client and not string.StartsWith(entity:GetClass(), "lia_") then SafeRemoveEntity(entity) end
    end
end

function GM:PlayerInitialSpawn(client)
    if client:IsBot() then
        hook.Run("SetupBotPlayer", client)
        return
    end

    lia.config.send(client)
    client.liaJoinTime = RealTime()
    client:loadLiliaData(function(data)
        if not IsValid(client) then return end
        local address = client:IPAddress()
        client:setLiliaData("lastIP", address)
        netstream.Start(client, "liaDataSync", data, client.firstJoin, client.lastJoin)
        for _, v in pairs(lia.item.instances) do
            if v.entity and v.invID == 0 then v:sync(client) end
        end

        hook.Run("PlayerLiliaDataLoaded", client)
    end)

    hook.Run("PostPlayerInitialSpawn", client)
end

function GM:PlayerLoadout(client)
    local character = client:getChar()
    if client.liaSkipLoadout then
        client.liaSkipLoadout = nil
        return
    end

    if not character then
        client:SetNoDraw(true)
        client:Lock()
        client:SetNotSolid(true)
        return
    end

    client:SetWeaponColor(Vector(0.30, 0.80, 0.10))
    client:StripWeapons()
    client:setLocalVar("blur", nil)
    client:SetModel(character:getModel())
    client:SetWalkSpeed(lia.config.get("WalkSpeed"))
    client:SetRunSpeed(lia.config.get("RunSpeed"))
    client:SetJumpPower(160)
    hook.Run("FactionOnLoadout", client)
    hook.Run("ClassOnLoadout", client)
    lia.flag.onSpawn(client)
    hook.Run("PostPlayerLoadout", client)
    hook.Run("FactionPostLoadout", client)
    hook.Run("ClassPostLoadout", client)
    client:SelectWeapon("lia_hands")
end

function GM:SetupBotPlayer(client)
    local botID = os.time()
    local index = math.random(1, table.Count(lia.faction.indices))
    local faction = lia.faction.indices[index]
    local inventory = lia.inventory.new("grid")
    local character = lia.char.new({
        name = client:Name(),
        faction = faction and faction.uniqueID or "unknown",
        desc = "This is a bot. BotID is " .. botID .. ".",
        model = "models/gman.mdl",
    }, botID, client, client:SteamID64())

    local defaultClass = lia.faction.getDefaultClass(faction.index)
    if defaultClass then character:joinClass(defaultClass.index) end
    character.isBot = true
    character.vars.inv = {}
    inventory.id = "bot" .. character:getID()
    character.vars.inv[1] = inventory
    lia.inventory.instances[inventory.id] = inventory
    lia.char.loaded[botID] = character
    character:setup()
    client:Spawn()
end

function GM:PlayerShouldTakeDamage(client)
    return client:getChar() ~= nil
end

function GM:CanDrive()
    return false
end

function GM:PlayerDeathThink()
    return false
end

function GM:SaveData()
    local data = {
        entities = {},
        items = {}
    }

    for _, ent in ents.Iterator() do
        if ent:isLiliaPersistent() then
            data.entities[#data.entities + 1] = {
                pos = ent:GetPos(),
                class = ent:GetClass(),
                model = ent:GetModel(),
                angles = ent:GetAngles(),
            }
        end
    end

    for _, item in ipairs(ents.FindByClass("lia_item")) do
        if item.liaItemID and not item.temp then data.items[#data.items + 1] = {item.liaItemID, item:GetPos()} end
    end

    lia.data.set("persistance", data.entities, true)
    lia.data.set("itemsave", data.items, true)
end

function GM:LoadData()
    local function IsEntityNearby(pos, class)
        for _, ent in ipairs(ents.FindByClass(class)) do
            if ent:GetPos():Distance(pos) <= 50 then return true end
        end
        return false
    end

    local entities = lia.data.get("persistance", {}, true)
    for _, ent in ipairs(entities or {}) do
        if not IsEntityNearby(ent.pos, ent.class) then
            local createdEnt = ents.Create(ent.class)
            if IsValid(createdEnt) then
                if ent.pos then createdEnt:SetPos(ent.pos) end
                if ent.angles then createdEnt:SetAngles(ent.angles) end
                if ent.model then createdEnt:SetModel(ent.model) end
                createdEnt:Spawn()
                createdEnt:Activate()
            end
        else
            LiliaError(string.format("Entity creation aborted: An entity of class '%s' is already nearby at position (%.2f, %.2f, %.2f).", ent.class, ent.pos.x, ent.pos.y, ent.pos.z))
        end
    end

    local items = lia.data.get("itemsave", {}, true)
    if items then
        local idRange = {}
        local positions = {}
        for _, item in ipairs(items) do
            idRange[#idRange + 1] = item[1]
            positions[item[1]] = item[2]
        end

        if #idRange > 0 then
            local range = "(" .. table.concat(idRange, ", ") .. ")"
            if hook.Run("ShouldDeleteSavedItems") == true then
                lia.db.query("DELETE FROM lia_items WHERE _itemID IN " .. range)
                LiliaInformation("Server Deleted Server Items (does not include Logical Items)")
            else
                lia.db.query("SELECT _itemID, _uniqueID, _data FROM lia_items WHERE _itemID IN " .. range, function(data)
                    if data then
                        local loadedItems = {}
                        for _, item in ipairs(data) do
                            local itemID = tonumber(item._itemID)
                            local itemData = util.JSONToTable(item._data or "[]")
                            local uniqueID = item._uniqueID
                            local itemTable = lia.item.list[uniqueID]
                            local position = positions[itemID]
                            if itemTable and itemID then
                                local itemCreated = lia.item.new(uniqueID, itemID)
                                itemCreated.data = itemData or {}
                                itemCreated:spawn(position).liaItemID = itemID
                                itemCreated:onRestored()
                                itemCreated.invID = 0
                                table.insert(loadedItems, itemCreated)
                            end
                        end

                        hook.Run("OnSavedItemLoaded", loadedItems)
                    end
                end)
            end
        end
    end
end

local function DatabaseQuery()
    if not DatabaseQueryRan then
        local typeMap = {
            string = function(d) return ("%s VARCHAR(%d)"):format(d.field, d.length or 255) end,
            integer = function(d) return ("%s INT"):format(d.field) end,
            float = function(d) return ("%s FLOAT"):format(d.field) end,
            boolean = function(d) return ("%s TINYINT(1)"):format(d.field) end,
            datetime = function(d) return ("%s DATETIME"):format(d.field) end,
            text = function(d) return ("%s TEXT"):format(d.field) end
        }

        local dbModule = lia.db.module or "sqlite"
        local getColumnsQuery = dbModule == "sqlite" and "SELECT sql FROM sqlite_master WHERE type='table' AND name='lia_characters'" or "DESCRIBE lia_characters"
        lia.db.query(getColumnsQuery, function(results)
            local existing = {}
            if results and #results > 0 then
                if dbModule == "sqlite" then
                    local createSQL = results[1].sql or ""
                    for def in createSQL:match("%((.+)%)"):gmatch("([^,]+)") do
                        local col = def:match("^%s*`?(%w+)`?")
                        if col then existing[col] = true end
                    end
                else
                    for _, row in ipairs(results) do
                        existing[row.Field] = true
                    end
                end
            end

            for _, v in pairs(lia.char.vars) do
                if v.field and not existing[v.field] and typeMap[v.fieldType] then
                    local colDef = typeMap[v.fieldType](v)
                    if v.default ~= nil then colDef = colDef .. " DEFAULT '" .. tostring(v.default) .. "'" end
                    local alter = ("ALTER TABLE lia_characters ADD COLUMN %s"):format(colDef)
                    lia.db.query(alter, function() MsgC(Color(83, 143, 239), "[Lilia] ", Color(0, 255, 0), "[Database] ", Color(255, 255, 255), string.format("Added missing column `%s`.\n", v.field)) end)
                end
            end
        end)

        DatabaseQueryRan = true
    end
end

function GM:InitializedModules()
    local bootstrapEndTime = SysTime()
    local timeTaken = bootstrapEndTime - BootingTime
    LiliaBootstrap("Bootstrapper", string.format("Lilia loaded in %.2f seconds.", timeTaken), Color(0, 255, 0))
    local addons = engine.GetAddons()
    local autoDownload = lia.config.get("AutoDownloadWorkshop", false)
    for _, addon in ipairs(addons) do
        if addon.wsid and addon.mounted then
            if autoDownload then
                resource.AddWorkshop(addon.wsid)
                LiliaInformation("[Workshop] Added Workshop addon: " .. addon.title .. " (WSID: " .. addon.wsid .. ")")
            end

            if addon.wsid == "1907060869" then LiliaError("WARNING: 'Srlion's Hook Library' (WSID: 1907060869) is known to cause issues and is not necessary for addons like SAM.") end
        end
    end

    timer.Simple(5, function() DatabaseQuery() end)
end
