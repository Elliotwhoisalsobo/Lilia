﻿local playerMeta = FindMetaTable("Player")
local vectorMeta = FindMetaTable("Vector")
do
    playerMeta.steamName = playerMeta.steamName or playerMeta.Name
    playerMeta.SteamName = playerMeta.steamName
    function playerMeta:getChar()
        return lia.char.loaded[self.getNetVar(self, "char")]
    end

    function playerMeta:Name()
        local character = self.getChar(self)
        return character and character.getName(character) or self.steamName(self)
    end

    playerMeta.GetCharacter = playerMeta.getChar
    playerMeta.Nick = playerMeta.Name
    playerMeta.GetName = playerMeta.Name
end

function playerMeta:hasPrivilege(privilegeName)
    return CAMI.PlayerHasAccess(self, privilegeName, nil)
end

function playerMeta:getCurrentVehicle()
    local vehicle = self:GetVehicle()
    if vehicle and IsValid(vehicle) then return vehicle end
    return nil
end

function playerMeta:hasValidVehicle()
    return IsValid(self:getCurrentVehicle())
end

function playerMeta:isNoClipping()
    return self:GetMoveType() == MOVETYPE_NOCLIP and not self:hasValidVehicle()
end

function playerMeta:hasRagdoll()
    return IsValid(self.liaRagdoll)
end

function playerMeta:removeRagdoll()
    if not self:hasRagdoll() then return end
    local ragdoll = self:getRagdoll()
    ragdoll.liaIgnoreDelete = true
    SafeRemoveEntity(ragdoll)
    self:setLocalVar("blur", nil)
end

function playerMeta:getRagdoll()
    if not self:hasRagdoll() then return end
    return self.liaRagdoll
end

function playerMeta:isStuck()
    return util.TraceEntity({
        start = self:GetPos(),
        endpos = self:GetPos(),
        filter = self
    }, self).StartSolid
end

function playerMeta:isNearPlayer(radius, entity)
    local squaredRadius = radius * radius
    local squaredDistance = self:GetPos():DistToSqr(entity:GetPos())
    return squaredDistance <= squaredRadius
end

function playerMeta:entitiesNearPlayer(radius, playerOnly)
    local nearbyEntities = {}
    for _, v in ipairs(ents.FindInSphere(self:GetPos(), radius)) do
        if playerOnly and not v:IsPlayer() then continue end
        table.insert(nearbyEntities, v)
    end
    return nearbyEntities
end

function playerMeta:getItemWeapon()
    local character = self:getChar()
    local inv = character:getInv()
    local items = inv:getItems()
    local weapon = self:GetActiveWeapon()
    if not IsValid(weapon) then return nil end
    for _, v in pairs(items) do
        if v.class then
            if v.class == weapon:GetClass() and v:getData("equip", false) then
                return weapon, v
            else
                return nil
            end
        end
    end
end

function playerMeta:isRunning()
    return vectorMeta.Length2D(self:GetVelocity()) > self:GetWalkSpeed() + 10
end

function playerMeta:isFemale()
    local model = self:GetModel():lower()
    return model:find("female") or model:find("alyx") or model:find("mossman")
end

function playerMeta:getItemDropPos()
    local data = {}
    data.start = self:GetShootPos()
    data.endpos = self:GetShootPos() + self:GetAimVector() * 86
    data.filter = self
    local trace = util.TraceLine(data)
    data.start = trace.HitPos
    data.endpos = data.start + trace.HitNormal * 46
    data.filter = {}
    trace = util.TraceLine(data)
    return trace.HitPos
end

function playerMeta:getItems()
    local character = self:getChar()
    if character then
        local inv = character:getInv()
        if inv then return inv:getItems() end
    end
end

function playerMeta:getTracedEntity()
    local data = {}
    data.start = self:GetShootPos()
    data.endpos = data.start + self:GetAimVector() * 96
    data.filter = self
    local targetEntity = util.TraceLine(data).Entity
    return targetEntity
end

function playerMeta:getTrace()
    local data = {}
    data.start = self:GetShootPos()
    data.endpos = data.start + self:GetAimVector() * 200
    data.filter = {self, self}
    data.mins = -Vector(4, 4, 4)
    data.maxs = Vector(4, 4, 4)
    local trace = util.TraceHull(data)
    return trace
end

function playerMeta:getEyeEnt(distance)
    distance = distance or 150
    local e = self:GetEyeTrace().Entity
    return e:GetPos():Distance(self:GetPos()) <= distance and e or nil
end

function playerMeta:notify(message, notifType)
    lia.notices.notify(message, notifType, self)
end

function playerMeta:notifyLocalized(message, ...)
    lia.notices.notifyLocalized(message, self, ...)
end

function playerMeta:notifyError(message)
    self:notify(message, 1)
end

function playerMeta:notifyCriticalError(message)
    self:notify(message, 2)
end

function playerMeta:notifyWarning(message)
    self:notify(message, 3)
end

function playerMeta:notifySuccess(message)
    self:notify(message, 4)
end

function playerMeta:notifyInfo(message)
    self:notify(message, 5)
end

function playerMeta:notifyHint(message)
    self:notify(message, 6)
end

function playerMeta:isFaction(faction)
    local character = self:getChar()
    if not character then return end
    local pFaction = self:getChar():getFaction()
    return pFaction and pFaction == faction
end

function playerMeta:isClass(class)
    local character = self:getChar()
    if not character then return end
    local pClass = character:getClass()
    return pClass and pClass == class
end

function playerMeta:hasWhitelist(faction)
    local data = lia.faction.indices[faction]
    if data then
        if data.isDefault then return true end
        if not data.uniqueID then return false end
        local liaData = self:getLiliaData("whitelists", {})
        return liaData[SCHEMA.folder] and liaData[SCHEMA.folder][data.uniqueID] or false
    end
    return false
end

function playerMeta:getClass()
    local character = self:getChar()
    if character then return character:getClass() end
end

function playerMeta:hasClassWhitelist(class)
    local char = self:getChar()
    if not char then return false end
    local wl = char:getData("whitelist", {})
    return wl[class] ~= nil
end

function playerMeta:getClassData()
    local character = self:getChar()
    if character then
        local class = character:getClass()
        if class then
            local classData = lia.class.list[class]
            return classData
        end
    end
end

function playerMeta:CanEditVendor()
    if self:hasPrivilege("Staff Permissions - Can Edit Vendors") then return true end
    return false
end

function playerMeta:hasSkillLevel(skill, level)
    local currentLevel = self:getChar():getAttrib(skill, 0)
    return currentLevel >= level
end

function playerMeta:meetsRequiredSkills(requiredSkillLevels)
    if not requiredSkillLevels then return true end
    for skill, level in pairs(requiredSkillLevels) do
        if not self:hasSkillLevel(skill, level) then return false end
    end
    return true
end

function playerMeta:getDarkRPVar(var)
    if var ~= "money" then return end
    local char = self:getChar()
    return char:getMoney()
end

function playerMeta:getMoney()
    local character = self:getChar()
    return character and character:getMoney() or 0
end

function playerMeta:canAfford(amount)
    local character = self:getChar()
    return character and character:hasMoney(amount)
end

function playerMeta:isUser()
    return self:IsUserGroup("user")
end

function playerMeta:isStaff()
    return self:hasPrivilege("UserGroups - Staff Group")
end

function playerMeta:isVIP()
    return self:hasPrivilege("UserGroups - VIP Group")
end

function playerMeta:isStaffOnDuty()
    return self:Team() == FACTION_STAFF
end

if SERVER then
    function playerMeta:restoreStamina(amount)
        local current = self:getLocalVar("stamina", 0)
        local maxStamina = self:getChar():getMaxStamina()
        local value = math.Clamp(current + amount, 0, maxStamina)
        self:setLocalVar("stamina", value)
        if value >= maxStamina * 0.5 and self:getNetVar("brth", false) then
            self:setNetVar("brth", nil)
            hook.Run("PlayerStaminaGained", self)
        end
    end

    function playerMeta:consumeStamina(amount)
        local current = self:getLocalVar("stamina", 0)
        local value = math.Clamp(current - amount, 0, self:getChar():getMaxStamina())
        self:setLocalVar("stamina", value)
        if value == 0 and not self:getNetVar("brth", false) then
            self:setNetVar("brth", true)
            hook.Run("PlayerStaminaLost", self)
        end
    end

    function playerMeta:addMoney(amount)
        local character = self:getChar()
        if not character then return false end
        local currentMoney = character:getMoney()
        local maxMoneyLimit = lia.config.get("MoneyLimit") or 0
        local totalMoney = currentMoney + amount
        if maxMoneyLimit > 0 and isnumber(maxMoneyLimit) and totalMoney > maxMoneyLimit then
            local excessMoney = totalMoney - maxMoneyLimit
            character:setMoney(maxMoneyLimit)
            self:notifyLocalized("moneyLimit", lia.currency.get(maxMoneyLimit), lia.currency.plural, lia.currency.get(excessMoney), lia.currency.plural)
            local money = lia.currency.spawn(self:getItemDropPos(), excessMoney)
            if IsValid(money) then
                money.client = self
                money.charID = character:getID()
            end

            lia.log.add(self, "money", maxMoneyLimit - currentMoney)
        else
            character:setMoney(totalMoney)
            lia.log.add(self, "money", amount)
        end
        return true
    end

    function playerMeta:takeMoney(amount)
        local character = self:getChar()
        if character then character:giveMoney(-amount) end
    end

    function playerMeta:WhitelistAllClasses()
        for class, _ in pairs(lia.class.list) do
            if lia.class.hasWhitelist(class) then self:classWhitelist(class) end
        end
    end

    function playerMeta:WhitelistAllFactions()
        for faction, _ in pairs(lia.faction.indices) do
            self:setWhitelisted(faction, true)
        end
    end

    function playerMeta:WhitelistEverything()
        self:WhitelistAllFactions()
        self:WhitelistAllClasses()
    end

    function playerMeta:classWhitelist(class)
        local wl = self:getChar():getData("whitelist", {})
        wl[class] = true
        self:getChar():setData("whitelist", wl)
    end

    function playerMeta:classUnWhitelist(class)
        local wl = self:getChar():getData("whitelist", {})
        wl[class] = false
        self:getChar():setData("whitelist", wl)
    end

    function playerMeta:setWhitelisted(faction, whitelisted)
        if not whitelisted then whitelisted = nil end
        local data = lia.faction.indices[faction]
        if data then
            local whitelists = self:getLiliaData("whitelists", {})
            whitelists[SCHEMA.folder] = whitelists[SCHEMA.folder] or {}
            whitelists[SCHEMA.folder][data.uniqueID] = whitelisted and true or nil
            self:setLiliaData("whitelists", whitelists)
            self:saveLiliaData()
            return true
        end
        return false
    end

    function playerMeta:loadLiliaData(callback)
        local name = self:steamName()
        local steamID64 = self:SteamID64()
        local timeStamp = os.date("%Y-%m-%d %H:%M:%S", os.time())
        lia.db.query("SELECT _data, _firstJoin, _lastJoin FROM lia_players WHERE _steamID = " .. steamID64, function(data)
            if IsValid(self) and data and data[1] and data[1]._data then
                lia.db.updateTable({
                    _lastJoin = timeStamp,
                }, nil, "players", "_steamID = " .. steamID64)

                self.firstJoin = data[1]._firstJoin or timeStamp
                self.lastJoin = data[1]._lastJoin or timeStamp
                self.liaData = util.JSONToTable(data[1]._data)
                if callback then callback(self.liaData) end
            else
                lia.db.insertTable({
                    _steamID = steamID64,
                    _steamName = name,
                    _firstJoin = timeStamp,
                    _lastJoin = timeStamp,
                    _data = {}
                }, nil, "players")

                if callback then callback({}) end
            end
        end)
    end

    function playerMeta:saveLiliaData()
        if self:IsBot() then return end
        local name = self:steamName()
        local steamID64 = self:SteamID64()
        local timeStamp = os.date("%Y-%m-%d %H:%M:%S", os.time())
        lia.db.updateTable({
            _steamName = name,
            _lastJoin = timeStamp,
            _data = self.liaData
        }, nil, "players", "_steamID = " .. steamID64)
    end

    function playerMeta:setLiliaData(key, value, noNetworking)
        self.liaData = self.liaData or {}
        self.liaData[key] = value
        if not noNetworking then netstream.Start(self, "liaData", key, value) end
    end

    function playerMeta:setWaypoint(name, vector)
        net.Start("setWaypoint")
        net.WriteString(name)
        net.WriteVector(vector)
        net.Send(self)
    end

    function playerMeta:setWeighPoint(name, vector)
        self:setWaypoint(name, vector)
    end

    function playerMeta:setWaypointWithLogo(name, vector, logo)
        net.Start("setWaypointWithLogo")
        net.WriteString(name)
        net.WriteVector(vector)
        net.WriteString(logo)
        net.Send(self)
    end

    function playerMeta:chatNotify(message)
        net.Start("chatNotify")
        net.WriteString(message)
        net.Send(self)
    end

    function playerMeta:chatNotifyLocalized(message, ...)
        local localizedMessage = L(message, self, ...)
        net.Start("chatNotify")
        net.WriteString(localizedMessage)
        net.Send(self)
    end

    function playerMeta:chatError(message)
        net.Start("chatError")
        net.WriteString(message)
        net.Send(self)
    end

    function playerMeta:chatErrorLocalized(message, ...)
        local localizedMessage = L(message, self, ...)
        net.Start("chatError")
        net.WriteString(localizedMessage)
        net.Send(self)
    end

    function playerMeta:getLiliaData(key, default)
        local data = self.liaData and self.liaData[key]
        if data == nil then
            return default
        else
            return data
        end
    end

    function playerMeta:getAllLiliaData()
        self.liaData = self.liaData or {}
        return self.liaData
    end

    function playerMeta:setRagdoll(entity)
        self.liaRagdoll = entity
    end

    function playerMeta:setAction(text, time, callback, startTime, finishTime)
        if time and time <= 0 then
            if callback then callback(self) end
            return
        end

        time = time or 5
        startTime = startTime or CurTime()
        finishTime = finishTime or startTime + time
        if text == false then
            timer.Remove("liaAct" .. self:SteamID64())
            netstream.Start(self, "actBar")
            return
        end

        netstream.Start(self, "actBar", startTime, finishTime, text)
        if callback then timer.Create("liaAct" .. self:SteamID64(), time, 1, function() if IsValid(self) then callback(self) end end) end
    end

    function playerMeta:stopAction()
        timer.Remove("liaAct" .. self:SteamID64())
        netstream.Start(self, "actBar")
    end

    function playerMeta:playSound(sound, volume, pitch, shouldEmit)
        volume = volume or 75
        pitch = pitch or 100
        if shouldEmit then
            self:EmitSound(sound, volume, pitch)
        else
            net.Start("PlaySound")
            net.WriteString(sound)
            net.WriteUInt(volume, 8)
            net.WriteUInt(pitch, 8)
            net.Send(self)
        end
    end

    function playerMeta:openUI(panel)
        net.Start("OpenVGUI")
        net.WriteString(panel)
        net.Send(self)
    end

    function playerMeta:openPage(url)
        net.Start("OpenPage")
        net.WriteString(url)
        net.Send(self)
    end

    function playerMeta:requestDropdown(title, subTitle, options, callback)
        net.Start("DropdownRequest")
        net.WriteString(title)
        net.WriteString(subTitle)
        net.WriteTable(options)
        net.Send(self)
        self.dropdownCallback = callback
    end

    function playerMeta:requestOptions(title, subTitle, options, limit, callback)
        net.Start("OptionsRequest")
        net.WriteString(title)
        net.WriteString(subTitle)
        net.WriteTable(options)
        net.WriteUInt(limit, 32)
        net.Send(self)
        self.optionsCallback = callback
    end

    function playerMeta:requestString(title, subTitle, callback, default)
        local d
        if not isfunction(callback) and default == nil then
            default = callback
            d = deferred.new()
            callback = function(value) d:resolve(value) end
        end

        self.liaStrReqs = self.liaStrReqs or {}
        local id = table.insert(self.liaStrReqs, callback)
        net.Start("StringRequest")
        net.WriteUInt(id, 32)
        net.WriteString(title)
        net.WriteString(subTitle)
        net.WriteString(default or "")
        net.Send(self)
        return d
    end

    function playerMeta:binaryQuestion(question, option1, option2, manualDismiss, callback)
        net.Start("BinaryQuestionRequest")
        net.WriteString(question)
        net.WriteString(option1)
        net.WriteString(option2)
        net.WriteBool(manualDismiss)
        net.Send(self)
        self.binaryQuestionCallback = callback
    end

    function playerMeta:getPlayTime()
        local diff = os.time(lia.time.toNumber(self.lastJoin)) - os.time(lia.time.toNumber(self.firstJoin))
        return diff + RealTime() - (self.liaJoinTime or RealTime())
    end

    function playerMeta:doStaredAction(entity, callback, time, onCancel, distance)
        local uniqueID = "liaStare" .. self:SteamID64()
        local data = {}
        data.filter = self
        timer.Create(uniqueID, 0.1, time / 0.1, function()
            if IsValid(self) and IsValid(entity) then
                data.start = self:GetShootPos()
                data.endpos = data.start + self:GetAimVector() * (distance or 96)
                local targetEntity = util.TraceLine(data).Entity
                if IsValid(targetEntity) and targetEntity:GetClass() == "prop_ragdoll" and IsValid(targetEntity:getNetVar("player")) then targetEntity = targetEntity:getNetVar("player") end
                if targetEntity ~= entity then
                    timer.Remove(uniqueID)
                    if onCancel then onCancel() end
                elseif callback and timer.RepsLeft(uniqueID) == 0 then
                    callback()
                end
            else
                timer.Remove(uniqueID)
                if onCancel then onCancel() end
            end
        end)
    end

    function playerMeta:getPlayTime()
        local diff = os.time(lia.time.toNumber(lia.lastJoin)) - os.time(lia.time.toNumber(lia.firstJoin))
        return diff + RealTime() - (lia.joinTime or 0)
    end

    function playerMeta:createRagdoll(freeze, isDead)
        local entity = ents.Create("prop_ragdoll")
        entity:SetPos(self:GetPos())
        entity:SetAngles(self:EyeAngles())
        entity:SetModel(self:GetModel())
        entity:SetSkin(self:GetSkin())
        entity:Spawn()
        entity:SetCollisionGroup(COLLISION_GROUP_WEAPON)
        entity:Activate()
        if isDead then self.liaRagdoll = entity end
        hook.Run("OnCreatePlayerRagdoll", self, entity, isDead)
        local velocity = self:GetVelocity()
        for i = 0, entity:GetPhysicsObjectCount() - 1 do
            local physObj = entity:GetPhysicsObjectNum(i)
            if IsValid(physObj) then
                local index = entity:TranslatePhysBoneToBone(i)
                if index then
                    local position, angles = self:GetBonePosition(index)
                    physObj:SetPos(position)
                    physObj:SetAngles(angles)
                end

                if freeze then
                    physObj:EnableMotion(false)
                else
                    physObj:SetVelocity(velocity)
                end
            end
        end
        return entity
    end

    function playerMeta:setRagdolled(state, time, getUpGrace, getUpMessage)
        getUpMessage = getUpMessage or L("wakingUp")
        local hasRagdoll = self:hasRagdoll()
        local ragdoll = self:getRagdoll()
        if state then
            if hasRagdoll then SafeRemoveEntity(ragdoll) end
            local entity = self:createRagdoll()
            entity:setNetVar("player", self)
            entity:CallOnRemove("fixer", function()
                if IsValid(self) then
                    self:setLocalVar("blur", nil)
                    self:setLocalVar("ragdoll", nil)
                    if not entity.liaNoReset then self:SetPos(entity:GetPos()) end
                    self:SetNoDraw(false)
                    self:SetNotSolid(false)
                    self:Freeze(false)
                    self:SetMoveType(MOVETYPE_WALK)
                    self:SetLocalVelocity(IsValid(entity) and entity.liaLastVelocity or vector_origin)
                end

                if IsValid(self) and not entity.liaIgnoreDelete then
                    if entity.liaWeapons then
                        for _, v in ipairs(entity.liaWeapons) do
                            self:Give(v, true)
                            if entity.liaAmmo then
                                for k2, v2 in ipairs(entity.liaAmmo) do
                                    if v == v2[1] then self:SetAmmo(v2[2], tostring(k2)) end
                                end
                            end
                        end
                    end

                    if self:isStuck() then
                        entity:DropToFloor()
                        self:SetPos(entity:GetPos() + Vector(0, 0, 16))
                        local positions = lia.util.findEmptySpace(self, {entity, self})
                        for _, v in ipairs(positions) do
                            self:SetPos(v)
                            if not self:isStuck() then return end
                        end
                    end
                end
            end)

            self:setLocalVar("blur", 25)
            self:setRagdoll(entity)
            entity.liaWeapons = {}
            entity.liaAmmo = {}
            entity.liaPlayer = self
            if getUpGrace then entity.liaGrace = CurTime() + getUpGrace end
            if time and time > 0 then
                entity.liaStart = CurTime()
                entity.liaFinish = entity.liaStart + time
                self:setAction(getUpMessage, nil, nil, entity.liaStart, entity.liaFinish)
            end

            for _, v in ipairs(self:GetWeapons()) do
                entity.liaWeapons[#entity.liaWeapons + 1] = v:GetClass()
                local clip = v:Clip1()
                local reserve = self:GetAmmoCount(v:GetPrimaryAmmoType())
                local ammo = clip + reserve
                entity.liaAmmo[v:GetPrimaryAmmoType()] = {v:GetClass(), ammo}
            end

            self:GodDisable()
            self:StripWeapons()
            self:Freeze(true)
            self:SetNoDraw(true)
            self:SetNotSolid(true)
            self:SetMoveType(MOVETYPE_NONE)
            if time then
                local uniqueID = "liaUnRagdoll" .. self:SteamID64()
                timer.Create(uniqueID, 0.33, 0, function()
                    if not IsValid(entity) or not IsValid(self) then
                        timer.Remove(uniqueID)
                        return
                    end

                    local velocity = entity:GetVelocity()
                    entity.liaLastVelocity = velocity
                    self:SetPos(entity:GetPos())
                    if velocity:Length2D() >= 8 and not entity.liaPausing then
                        self:stopAction()
                        entity.liaPausing = true
                        return
                    elseif entity.liaPausing then
                        self:setAction(getUpMessage, time)
                        entity.liaPausing = false
                    end

                    time = time - 0.33
                    if time <= 0 then SafeRemoveEntity(entity) end
                end)
            end

            self:setLocalVar("ragdoll", entity:EntIndex())
            if IsValid(entity) then
                entity:SetCollisionGroup(COLLISION_GROUP_NONE)
                entity:SetCustomCollisionCheck(false)
            end
        elseif hasRagdoll then
            SafeRemoveEntity(self.liaRagdoll)
            hook.Run("OnCharFallover", self, nil, false)
        end
    end

    function playerMeta:syncVars()
        for entity, data in pairs(lia.net) do
            if entity == "globals" then
                for k, v in pairs(data) do
                    netstream.Start(self, "gVar", k, v)
                end
            elseif IsValid(entity) then
                for k, v in pairs(data) do
                    netstream.Start(self, "nVar", entity:EntIndex(), k, v)
                end
            end
        end
    end

    function playerMeta:setLocalVar(key, value)
        if checkBadType(key, value) then return end
        lia.net[self] = lia.net[self] or {}
        lia.net[self][key] = value
        netstream.Start(self, "nLcl", key, value)
    end

    playerMeta.SetLocalVar = playerMeta.setLocalVar
else
    function playerMeta:chatNotify(message)
        chat.AddText(Color(0, 200, 255), "[NOTIFICATION]: ", Color(255, 255, 255), message)
    end

    function playerMeta:chatError(message)
        chat.AddText(Color(255, 0, 0), "[ERROR]: ", Color(255, 255, 255), message)
    end

    function playerMeta:chatNotifyLocalized(message, ...)
        local client = LocalPlayer()
        if self == client then
            message = L(message, ...)
            chat.AddText(Color(255, 215, 0), message)
        end
    end

    function playerMeta:getPlayTime()
        local diff = os.time(lia.time.toNumber(lia.lastJoin)) - os.time(lia.time.toNumber(lia.firstJoin))
        return diff + RealTime() - (lia.joinTime or 0)
    end

    function playerMeta:setWaypoint(name, vector, onReach)
        hook.Add("HUDPaint", "WeighPoint", function()
            if not IsValid(self) then
                hook.Remove("HUDPaint", "WeighPoint")
                return
            end

            local dist = self:GetPos():Distance(vector)
            local spos = vector:ToScreen()
            local howclose = math.Round(dist / 40)
            if spos.visible then
                render.SuppressEngineLighting(true)
                surface.SetFont("liaBigFont")
                draw.DrawText(name .. "\n" .. howclose .. " Meters\n", "liaBigFont", spos.x, spos.y, Color(255, 255, 255), TEXT_ALIGN_CENTER)
                render.SuppressEngineLighting(false)
            end

            if howclose <= 3 then RunConsoleCommand("weighpoint_stop") end
        end)

        concommand.Add("weighpoint_stop", function()
            hook.Remove("HUDPaint", "WeighPoint")
            if onReach and isfunction(onReach) then onReach() end
        end)
    end

    function playerMeta:setWeighPoint(name, vector, onReach)
        self:setWaypoint(name, vector, onReach)
    end

    function playerMeta:setWaypointWithLogo(name, vector, logo, onReach)
        if not isstring(name) or not isvector(vector) then return end
        local logoMaterial
        if logo and isstring(logo) then
            logoMaterial = Material(logo, "smooth mips noclamp")
            if not logoMaterial or logoMaterial:IsError() then logoMaterial = nil end
        end

        if not logoMaterial then return end
        local waypointID = "Waypoint_WithLogo_" .. tostring(self:SteamID64()) .. "_" .. tostring(math.random(100000, 999999))
        hook.Add("HUDPaint", waypointID, function()
            if not IsValid(self) then
                hook.Remove("HUDPaint", waypointID)
                return
            end

            local dist = self:GetPos():Distance(vector)
            local spos = vector:ToScreen()
            local howClose = math.Round(dist / 40)
            if spos.visible then
                if logoMaterial then
                    local logoSize = 32
                    surface.SetDrawColor(255, 255, 255, 255)
                    surface.SetMaterial(logoMaterial)
                    surface.DrawTexturedRect(spos.x - logoSize / 2, spos.y - logoSize / 2 - 40, logoSize, logoSize)
                end

                draw.DrawText(name .. "\n" .. howClose .. " Meters", "liaBigFont", spos.x, spos.y - 10, Color(255, 255, 255), TEXT_ALIGN_CENTER)
            end

            if howClose <= 3 then RunConsoleCommand("waypoint_withlogo_stop_" .. waypointID) end
        end)

        concommand.Add("waypoint_withlogo_stop_" .. waypointID, function()
            hook.Remove("HUDPaint", waypointID)
            concommand.Remove("waypoint_withlogo_stop_" .. waypointID)
            if onReach and isfunction(onReach) then onReach(self) end
        end)
    end

    function playerMeta:getLiliaData(key, default)
        local data = lia.localData and lia.localData[key]
        if data == nil then
            return default
        else
            return data
        end
    end

    function playerMeta:getAllLiliaData()
        lia.localData = lia.localData or {}
        return lia.localData
    end
end