﻿net.Receive("liaNotifyL", function()
    local message = net.ReadString()
    local length = net.ReadUInt(8)
    if length == 0 then return lia.notices.notifyLocalized(message) end
    local args = {}
    for i = 1, length do
        args[i] = net.ReadString()
    end

    lia.notices.notifyLocalized(message, unpack(args))
end)

net.Receive("setWaypoint", function()
    local name = net.ReadString()
    local pos = net.ReadVector()
    LocalPlayer():setWaypoint(name, pos)
end)

net.Receive("setWaypointWithLogo", function()
    local name = net.ReadString()
    local pos = net.ReadVector()
    local logo = net.ReadString()
    LocalPlayer():setWaypointWithLogo(name, pos, logo)
end)

net.Receive("liaNotify", function()
    local message = net.ReadString()
    local notifType = net.ReadUInt(3)
    lia.notices.notify(message, notifType)
end)

net.Receive("sendURL", function()
    local url = net.ReadString()
    gui.OpenURL(url)
end)

net.Receive("ServerChatAddText", function()
    local args = net.ReadTable()
    chat.AddText(unpack(args))
end)

net.Receive("liaInventoryData", function()
    local id = net.ReadType()
    local key = net.ReadString()
    local value = net.ReadType()
    local instance = lia.inventory.instances[id]
    if not instance then
        ErrorNoHalt("Got data " .. key .. " for non-existent instance " .. id)
        return
    end

    local oldValue = instance.data[key]
    instance.data[key] = value
    instance:onDataChanged(key, oldValue, value)
    hook.Run("InventoryDataChanged", instance, key, oldValue, value)
end)

net.Receive("liaInventoryInit", function()
    local id = net.ReadType()
    local typeID = net.ReadString()
    local data = net.ReadTable()
    local instance = lia.inventory.new(typeID)
    instance.id = id
    instance.data = data
    instance.items = {}
    local length = net.ReadUInt(32)
    local data2 = net.ReadData(length)
    local uncompressed_data = util.Decompress(data2)
    local items = util.JSONToTable(uncompressed_data)
    local function readItem(I)
        local c = items[I]
        return c.i, c.u, c.d, c.q
    end

    local datatable = items
    local expectedItems = #datatable
    for i = 1, expectedItems do
        local itemID, itemType, data, quantity = readItem(i)
        local item = lia.item.new(itemType, itemID)
        item.data = table.Merge(item.data, data)
        item.invID = instance.id
        item.quantity = quantity
        instance.items[itemID] = item
        hook.Run("ItemInitialized", item)
    end

    lia.inventory.instances[instance.id] = instance
    hook.Run("InventoryInitialized", instance)
    for _, character in pairs(lia.char.loaded) do
        for index, inventory in pairs(character.vars.inv) do
            if inventory:getID() == id then character.vars.inv[index] = instance end
        end
    end
end)

net.Receive("liaInventoryAdd", function()
    local itemID = net.ReadUInt(32)
    local invID = net.ReadType()
    local item = lia.item.instances[itemID]
    local inventory = lia.inventory.instances[invID]
    if item and inventory then
        inventory.items[itemID] = item
        hook.Run("InventoryItemAdded", inventory, item)
    end
end)

net.Receive("liaInventoryRemove", function()
    local itemID = net.ReadUInt(32)
    local invID = net.ReadType()
    local item = lia.item.instances[itemID]
    local inventory = lia.inventory.instances[invID]
    if item and inventory and inventory.items[itemID] then
        inventory.items[itemID] = nil
        item.invID = 0
        hook.Run("InventoryItemRemoved", inventory, item)
    end
end)

net.Receive("liaInventoryDelete", function()
    local invID = net.ReadType()
    local instance = lia.inventory.instances[invID]
    if instance then hook.Run("InventoryDeleted", instance) end
    if invID then lia.inventory.instances[invID] = nil end
end)

net.Receive("liaItemInstance", function()
    local itemID = net.ReadUInt(32)
    local itemType = net.ReadString()
    local data = net.ReadTable()
    local item = lia.item.new(itemType, itemID)
    local invID = net.ReadType()
    local quantity = net.ReadUInt(32)
    item.data = table.Merge(item.data or {}, data)
    item.invID = invID
    item.quantity = quantity
    lia.item.instances[itemID] = item
    hook.Run("ItemInitialized", item)
end)

net.Receive("liaCharacterInvList", function()
    local charID = net.ReadUInt(32)
    local length = net.ReadUInt(32)
    local inventories = {}
    for i = 1, length do
        inventories[i] = lia.inventory.instances[net.ReadType()]
    end

    local character = lia.char.loaded[charID]
    if character then character.vars.inv = inventories end
end)

net.Receive("liaItemDelete", function()
    local id = net.ReadUInt(32)
    local instance = lia.item.instances[id]
    if instance and instance.invID then
        local inventory = lia.inventory.instances[instance.invID]
        if not inventory or not inventory.items[id] then return end
        inventory.items[id] = nil
        instance.invID = 0
        hook.Run("InventoryItemRemoved", inventory, instance)
    end

    lia.item.instances[id] = nil
    hook.Run("ItemDeleted", instance)
end)

netstream.Hook("charSet", function(key, value, id)
    id = id or LocalPlayer():getChar() and LocalPlayer():getChar().id
    local character = lia.char.loaded[id]
    if character then
        local oldValue = character.vars[key]
        character.vars[key] = value
        hook.Run("OnCharVarChanged", character, key, oldValue, value)
    end
end)

netstream.Hook("charVar", function(key, value, id)
    id = id or LocalPlayer():getChar() and LocalPlayer():getChar().id
    local character = lia.char.loaded[id]
    if character then
        local oldVar = character:getVar()[key]
        character:getVar()[key] = value
        hook.Run("OnCharLocalVarChanged", character, key, oldVar, value)
    end
end)

netstream.Hook("charData", function(id, key, value)
    local character = lia.char.loaded[id]
    if character then
        character.vars.data = character.vars.data or {}
        character:getData()[key] = value
    end
end)

netstream.Hook("item", function(uniqueID, id, data, invID)
    local item = lia.item.new(uniqueID, id)
    item.data = {}
    if data then item.data = data end
    item.invID = invID or 0
    hook.Run("ItemInitialized", item)
end)

netstream.Hook("invData", function(id, key, value)
    local item = lia.item.instances[id]
    if item then
        item.data = item.data or {}
        local oldValue = item.data[key]
        item.data[key] = value
        hook.Run("ItemDataChanged", item, key, oldValue, value)
    end
end)

netstream.Hook("invQuantity", function(id, quantity)
    local item = lia.item.instances[id]
    if item then
        local oldValue = item:getQuantity()
        item.quantity = quantity
        hook.Run("ItemQuantityChanged", item, oldValue, quantity)
    end
end)

netstream.Hook("liaDataSync", function(data, first, last)
    lia.localData = data
    lia.firstJoin = first
    lia.lastJoin = last
end)

netstream.Hook("liaData", function(key, value)
    lia.localData = lia.localData or {}
    lia.localData[key] = value
end)

netstream.Hook("attrib", function(id, key, value)
    local character = lia.char.loaded[id]
    if character then character:getAttribs()[key] = value end
end)

netstream.Hook("nVar", function(index, key, value)
    lia.net[index] = lia.net[index] or {}
    lia.net[index][key] = value
end)

netstream.Hook("nLcl", function(key, value)
    lia.net[LocalPlayer():EntIndex()] = lia.net[LocalPlayer():EntIndex()] or {}
    lia.net[LocalPlayer():EntIndex()][key] = value
end)

netstream.Hook("actBar", function(start, finish, text)
    if not text then
        lia.bar.actionStart = 0
        lia.bar.actionEnd = 0
    else
        if text:sub(1, 1) == "@" then text = L(text:sub(2)) end
        lia.bar.actionStart = start
        lia.bar.actionEnd = finish
        lia.bar.actionText = text:upper()
    end
end)

net.Receive("OpenInvMenu", function()
    if not LocalPlayer():hasPrivilege("Commands - Check Inventories") then return end
    local target = net.ReadEntity()
    local index = net.ReadType()
    local targetInv = lia.inventory.instances[index]
    local myInv = LocalPlayer():getChar():getInv()
    local inventoryDerma = targetInv:show()
    inventoryDerma:SetTitle(target:getChar():getName() .. "'s Inventory")
    inventoryDerma:MakePopup()
    inventoryDerma:ShowCloseButton(true)
    local myInventoryDerma = myInv:show()
    myInventoryDerma:MakePopup()
    myInventoryDerma:ShowCloseButton(true)
    myInventoryDerma:SetParent(inventoryDerma)
    myInventoryDerma:MoveLeftOf(inventoryDerma, 4)
end)

net.Receive("CreateTableUI", function()
    local dataSize = net.ReadUInt(32)
    local compressedData = net.ReadData(dataSize)
    local jsonData = util.Decompress(compressedData)
    local data = util.JSONToTable(jsonData)
    lia.util.CreateTableUI(data.title, data.columns, data.data, data.options, data.characterID)
end)

net.Receive("OpenVGUI", function()
    local panel = net.ReadString()
    LocalPlayer():openUI(panel)
end)

net.Receive("chatNotify", function()
    local message = net.ReadString()
    chat.AddText(Color(0, 200, 255), "[NOTIFICATION]: ", Color(255, 255, 255), message)
end)

net.Receive("chatError", function()
    local message = net.ReadString()
    chat.AddText(Color(255, 0, 0), "[ERROR]: ", Color(255, 255, 255), message)
end)

net.Receive("OptionsRequest", function()
    local title = L(net.ReadString())
    local subTitle = L(net.ReadString())
    local options = net.ReadTable()
    local limit = net.ReadUInt(32)
    local frame = vgui.Create("DFrame")
    frame:SetTitle(title)
    frame:SetSize(400, 300)
    frame:Center()
    frame:MakePopup()
    local label = vgui.Create("DLabel", frame)
    label:SetText(subTitle)
    label:SetPos(10, 30)
    label:SizeToContents()
    label:SetTextColor(Color(255, 255, 255))
    local list = vgui.Create("DPanelList", frame)
    list:SetPos(10, 50)
    list:SetSize(380, 200)
    list:EnableVerticalScrollbar(true)
    list:SetSpacing(5)
    local selected = {}
    local checkboxes = {}
    for _, option in ipairs(options) do
        local localizedOption = L(option)
        local checkbox = vgui.Create("DCheckBoxLabel")
        checkbox:SetText(localizedOption)
        checkbox:SetValue(false)
        checkbox:SizeToContents()
        checkbox:SetTextColor(Color(255, 255, 255))
        checkbox.OnChange = function(self, value)
            if value then
                if #selected < limit then
                    table.insert(selected, option)
                else
                    self:SetValue(false)
                end
            else
                for i, v in ipairs(selected) do
                    if v == option then
                        table.remove(selected, i)
                        break
                    end
                end
            end
        end

        list:AddItem(checkbox)
        table.insert(checkboxes, checkbox)
    end

    local button = vgui.Create("DButton", frame)
    button:SetText(L("submit"))
    button:SetPos(10, 260)
    button:SetSize(380, 30)
    button.DoClick = function()
        net.Start("OptionsRequest")
        net.WriteTable(selected)
        net.SendToServer()
        frame:Close()
    end
end)

net.Receive("DropdownRequest", function()
    local title = L(net.ReadString())
    local subTitle = L(net.ReadString())
    local options = net.ReadTable()
    local frame = vgui.Create("DFrame")
    frame:SetTitle(title)
    frame:SetSize(300, 150)
    frame:Center()
    frame:MakePopup()
    local dropdown = vgui.Create("DComboBox", frame)
    dropdown:SetPos(10, 40)
    dropdown:SetSize(280, 20)
    dropdown:SetValue(subTitle)
    for _, option in ipairs(options) do
        dropdown:AddChoice(L(option))
    end

    dropdown.OnSelect = function(_, _, value)
        net.Start("DropdownRequest")
        net.WriteString(value)
        net.SendToServer()
        frame:Close()
    end
end)

net.Receive("StringRequest", function()
    local id = net.ReadUInt(32)
    local title = net.ReadString()
    local subTitle = net.ReadString()
    local default = net.ReadString()
    if title:sub(1, 1) == "@" then title = L(title:sub(2)) end
    if subTitle:sub(1, 1) == "@" then subTitle = L(subTitle:sub(2)) end
    Derma_StringRequest(title, subTitle, default, function(text)
        net.Start("StringRequest")
        net.WriteUInt(id, 32)
        net.WriteString(text)
        net.SendToServer()
    end)
end)

net.Receive("BinaryQuestionRequest", function()
    local question = L(net.ReadString())
    local option1 = L(net.ReadString(), "Yes")
    local option2 = L(net.ReadString(), "No")
    local manualDismiss = net.ReadBool()
    local notice = CreateNoticePanel(10, manualDismiss)
    table.insert(lia.notices, notice)
    notice.isQuery = true
    notice.text:SetText(question)
    notice:SetPos(ScrW() / 2 - notice:GetWide() / 2, 4)
    notice:SetTall(36 * 2.3)
    notice:CalcWidth(120)
    if manualDismiss then notice.start = nil end
    notice.opt1 = notice:Add("DButton")
    notice.opt1:SetAlpha(0)
    notice.opt2 = notice:Add("DButton")
    notice.opt2:SetAlpha(0)
    notice.oh = notice:GetTall()
    notice:SetTall(0)
    notice:SizeTo(notice:GetWide(), 36 * 2.3, 0.2, 0, -1, function()
        notice.text:SetPos(0, 0)
        local function styleOpt(o)
            o.color = Color(0, 0, 0, 30)
            AccessorFunc(o, "color", "Color")
            function o:Paint(w, h)
                if self.left then
                    draw.RoundedBoxEx(4, 0, 0, w + 2, h, self.color, false, false, true, false)
                else
                    draw.RoundedBoxEx(4, 0, 0, w + 2, h, self.color, false, false, false, true)
                end
            end
        end

        if notice.opt1 and IsValid(notice.opt1) then
            notice.opt1:SetAlpha(255)
            notice.opt1:SetSize(notice:GetWide() / 2, 25)
            notice.opt1:SetText(option1 .. " (F8)")
            notice.opt1:SetPos(0, notice:GetTall() - notice.opt1:GetTall())
            notice.opt1:CenterHorizontal(0.25)
            notice.opt1:SetAlpha(0)
            notice.opt1:AlphaTo(255, 0.2)
            notice.opt1:SetTextColor(color_white)
            notice.opt1.left = true
            styleOpt(notice.opt1)
            function notice.opt1:keyThink()
                if input.IsKeyDown(KEY_F8) and CurTime() - notice.lastKey >= 0.5 then
                    self:ColorTo(Color(24, 215, 37), 0.2, 0)
                    notice.respondToKeys = false
                    net.Start("BinaryQuestionRequest")
                    net.WriteUInt(0, 1)
                    net.SendToServer()
                    timer.Simple(1, function() if notice and IsValid(notice) then RemoveNotices(notice) end end)
                    notice.lastKey = CurTime()
                end
            end
        end

        if notice.opt2 and IsValid(notice.opt2) then
            notice.opt2:SetAlpha(255)
            notice.opt2:SetSize(notice:GetWide() / 2, 25)
            notice.opt2:SetText(option2 .. " (F9)")
            notice.opt2:SetPos(0, notice:GetTall() - notice.opt2:GetTall())
            notice.opt2:CenterHorizontal(0.75)
            notice.opt2:SetAlpha(0)
            notice.opt2:AlphaTo(255, 0.2)
            notice.opt2:SetTextColor(color_white)
            styleOpt(notice.opt2)
            function notice.opt2:keyThink()
                if input.IsKeyDown(KEY_F9) and CurTime() - notice.lastKey >= 0.5 then
                    self:ColorTo(Color(24, 215, 37), 0.2, 0)
                    notice.respondToKeys = false
                    net.Start("BinaryQuestionRequest")
                    net.WriteUInt(1, 1)
                    net.SendToServer()
                    timer.Simple(1, function() if notice and IsValid(notice) then RemoveNotices(notice) end end)
                    notice.lastKey = CurTime()
                end
            end
        end

        notice.lastKey = CurTime()
        notice.respondToKeys = true
        function notice:Think()
            self:SetPos(ScrW() / 2 - self:GetWide() / 2, 4)
            if not self.respondToKeys then return end
            if self.opt1 and IsValid(self.opt1) then self.opt1:keyThink() end
            if self.opt2 and IsValid(self.opt2) then self.opt2:keyThink() end
        end
    end)
end)

net.Receive("OpenPage", function() gui.OpenURL(net.ReadString()) end)
netstream.Hook("charInfo", function(data, id, client) lia.char.loaded[id] = lia.char.new(data, id, client == nil and LocalPlayer() or client) end)
netstream.Hook("charKick", function(id, isCurrentChar) hook.Run("KickedFromChar", id, isCurrentChar) end)
netstream.Hook("gVar", function(key, value) lia.net.globals[key] = value end)
netstream.Hook("nDel", function(index) lia.net[index] = nil end)
