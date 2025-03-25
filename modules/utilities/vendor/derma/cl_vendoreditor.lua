﻿local MODULE = MODULE
local PANEL = {}
local EDITOR = include(MODULE.path .. "/libs/cl_vendor.lua")
local COLS_MODE = 2
local COLS_PRICE = 3
local COLS_STOCK = 4
function PANEL:Init()
    if IsValid(lia.gui.vendorEditor) then lia.gui.vendorEditor:Remove() end
    lia.gui.vendorEditor = self
    local entity = liaVendorEnt
    local width = math.min(ScrW() * 0.75, 480)
    local height = math.min(ScrH() * 0.75, 640)
    self:SetSize(width, height)
    self:MakePopup()
    self:Center()
    self:SetTitle(L("vendorEditor"))
    self.name = self:Add("DTextEntry")
    self.name:Dock(TOP)
    self.name:SetTooltip(L("name"))
    self.name:SetText(entity:getName())
    self.name.OnEnter = function(this) if entity:getNetVar("name") ~= this:GetText() then EDITOR.name(this:GetText()) end end
    self.model = self:Add("DTextEntry")
    self.model:Dock(TOP)
    self.model:SetTooltip(L("model"))
    self.model:DockMargin(0, 4, 0, 0)
    self.model:SetText(entity:GetModel())
    self.model.OnEnter = function(this)
        local modelText = this:GetText():lower()
        if entity:GetModel():lower() ~= modelText then EDITOR.model(modelText) end
    end

    self.flag = self:Add("DTextEntry")
    self.flag:Dock(TOP)
    self.flag:DockMargin(0, 4, 0, 0)
    self.flag:SetText(entity:getNetVar("flag") or L("flag"))
    self.flag.OnEnter = function(this)
        local value = this:GetText()
        if value:match("^%a$") then
            EDITOR.flag(value)
        else
            local correctedValue = value:sub(1, 1):match("^%a$") and value:sub(1, 1) or "F"
            this:SetText(correctedValue)
            EDITOR.flag(correctedValue)
        end
    end

    self.welcome = self:Add("DTextEntry")
    self.welcome:Dock(TOP)
    self.welcome:DockMargin(0, 4, 0, 0)
    self.welcome:SetText(entity:getWelcomeMessage())
    self.welcome:SetTooltip(L("vendorEditorWelcomeMessage"))
    self.welcome.OnEnter = function(this)
        local msg = this:GetText()
        if msg ~= entity:getWelcomeMessage() then EDITOR.welcome(msg) end
    end

    self.money = self:Add("DTextEntry")
    self.money:Dock(TOP)
    self.money:SetTooltip(lia.currency.plural)
    self.money:DockMargin(0, 4, 0, 0)
    self.money:SetNumeric(true)
    self.money.OnEnter = function(this)
        local value = tonumber(this:GetText()) or entity:getMoney()
        value = math.Round(value)
        value = math.max(value, 0)
        if value ~= entity:getMoney() then EDITOR.money(value) end
    end

    self.useMoney = self:Add("DCheckBoxLabel")
    self.useMoney:SetText(L("vendorUseMoney"))
    self.useMoney:Dock(TOP)
    self.useMoney:SetTextColor(Color(255, 255, 255))
    self.useMoney:DockMargin(0, 4, 0, 0)
    self.useMoney.OnChange = function(_, value) EDITOR.useMoney(value) end
    self.sellScale = self:Add("DNumSlider")
    self.sellScale:Dock(TOP)
    self.sellScale:DockMargin(0, 4, 0, 0)
    self.sellScale:SetText(L("vendorSellScale"))
    self.sellScale.Label:SetTextColor(color_white)
    self.sellScale.TextArea:SetTextColor(color_white)
    self.sellScale:SetDecimals(2)
    self.sellScale.OnValueChanged = function(_, value)
        timer.Create("VendorScale", 0.5, 1, function()
            if IsValid(self) and IsValid(self.sellScale) then
                value = self.sellScale:GetValue()
                local diff = math.abs(value - entity:getSellScale())
                if diff > 0.05 then EDITOR.scale(value) end
            end
        end)
    end

    self.faction = self:Add("DButton")
    self.faction:SetText(L("vendorFaction"))
    self.faction:Dock(TOP)
    self.faction:SetTextColor(color_white)
    self.faction:DockMargin(0, 4, 0, 0)
    self.faction.DoClick = function() vgui.Create("VendorFactionEditor"):MoveLeftOf(self, 4) end
    self.items = self:Add("DListView")
    self.items:Dock(FILL)
    self.items:DockMargin(0, 4, 0, 0)
    self.items:AddColumn(L("vendorName")).Header:SetTextColor(color_white)
    self.items:AddColumn(L("vendorMode")).Header:SetTextColor(color_white)
    self.items:AddColumn(L("vendorPrice")).Header:SetTextColor(color_white)
    self.items:AddColumn(L("vendorStock")).Header:SetTextColor(color_white)
    self.items:AddColumn(L("vendorCategory")).Header:SetTextColor(color_white)
    self.items:SetMultiSelect(false)
    self.items.OnRowRightClick = function(_, _, line) self:OnRowRightClick(line) end
    self.searchBar = self:Add("DTextEntry")
    self.searchBar:Dock(TOP)
    self.searchBar:DockMargin(0, 4, 0, 0)
    self.searchBar:SetUpdateOnType(true)
    self.searchBar:SetPlaceholderText(L("search"))
    self.searchBar.OnValueChange = function(_, value) self:ReloadItemList(value) end
    self.lines = {}
    self:ReloadItemList()
    self:listenForUpdates()
    self:updateMoney()
    self:updateSellScale()
end

function PANEL:getModeText(mode)
    return mode and L(VENDOR_TEXT[mode]) or L("vendorNone")
end

function PANEL:OnRemove()
    if IsValid(lia.gui.editorFaction) then lia.gui.editorFaction:Remove() end
end

function PANEL:updateVendor(key, value)
    netstream.Start("vendorEdit", key, value)
end

function PANEL:OnFocusChanged(gained)
    if not gained then
        timer.Simple(0, function()
            if not IsValid(self) then return end
            self:MakePopup()
        end)
    end
end

function PANEL:updateMoney()
    local money = liaVendorEnt:getMoney()
    local useMoney = isnumber(money)
    if money then
        self.money:SetText(money)
    else
        self.money:SetText("∞")
    end

    self.money:SetDisabled(not useMoney)
    self.money:SetEnabled(useMoney)
    self.useMoney:SetChecked(useMoney)
end

function PANEL:updateSellScale()
    self.sellScale:SetValue(liaVendorEnt:getSellScale())
end

function PANEL:onNameDescChanged(key)
    local entity = liaVendorEnt
    if key == "name" then
        self.name:SetText(entity:getName())
    elseif key == "model" then
        self.model:SetText(entity:GetModel())
    elseif key == "scale" then
        self:updateSellScale()
    elseif key == "welcome" and entity.getWelcomeMessage then
        self.welcome:SetText(entity:getWelcomeMessage())
    end
end

function PANEL:onItemModeUpdated(_, itemType, value)
    local line = self.lines[itemType]
    if not IsValid(line) then return end
    line:SetColumnText(COLS_MODE, self:getModeText(value))
end

function PANEL:onItemPriceUpdated(vendor, itemType)
    local line = self.lines[itemType]
    if not IsValid(line) then return end
    line:SetColumnText(COLS_PRICE, vendor:getPrice(itemType))
end

function PANEL:onItemStockUpdated(vendor, itemType)
    local line = self.lines[itemType]
    if not IsValid(line) then return end
    local current, max = vendor:getStock(itemType)
    line:SetColumnText(COLS_STOCK, max and current .. "/" .. max or "-")
end

function PANEL:listenForUpdates()
    hook.Add("VendorEdited", self, self.onNameDescChanged)
    hook.Add("VendorMoneyUpdated", self, self.updateMoney)
    hook.Add("VendorItemModeUpdated", self, self.onItemModeUpdated)
    hook.Add("VendorItemPriceUpdated", self, self.onItemPriceUpdated)
    hook.Add("VendorItemStockUpdated", self, self.onItemStockUpdated)
    hook.Add("VendorItemMaxStockUpdated", self, self.onItemStockUpdated)
end

function PANEL:OnRowRightClick(line)
    local entity = liaVendorEnt
    if IsValid(menu) then menu:Remove() end
    local uniqueID = line.item
    local itemTable = lia.item.list[uniqueID]
    menu = DermaMenu()
    local mode, panel = menu:AddSubMenu(L("mode"))
    panel:SetImage("icon16/key.png")
    mode:AddOption(L("none"), function() EDITOR.mode(uniqueID, nil) end):SetImage("icon16/cog_error.png")
    mode:AddOption(L("vendorBoth"), function() EDITOR.mode(uniqueID, VENDOR_SELLANDBUY) end):SetImage("icon16/cog.png")
    mode:AddOption(L("vendorBuy"), function() EDITOR.mode(uniqueID, VENDOR_BUYONLY) end):SetImage("icon16/cog_delete.png")
    mode:AddOption(L("vendorSell"), function() EDITOR.mode(uniqueID, VENDOR_SELLONLY) end):SetImage("icon16/cog_add.png")
    menu:AddOption(L("price"), function()
        Derma_StringRequest(itemTable:getName(), L("vendorPriceReq"), entity:getPrice(uniqueID), function(text)
            text = tonumber(text)
            EDITOR.price(uniqueID, text)
        end)
    end):SetImage("icon16/coins.png")

    local stock, panel = menu:AddSubMenu(L("stock"))
    panel:SetImage("icon16/table.png")
    stock:AddOption(L("disable"), function() EDITOR.stockDisable(uniqueID) end):SetImage("icon16/table_delete.png")
    stock:AddOption(L("edit"), function()
        local _, max = entity:getStock(uniqueID)
        Derma_StringRequest(itemTable:getName(), L("vendorStockReq"), max or 1, function(text)
            text = math.max(math.Round(tonumber(text) or 1), 1)
            EDITOR.stockMax(uniqueID, text)
        end)
    end):SetImage("icon16/table_edit.png")

    stock:AddOption(L("vendorEditCurStock"), function()
        Derma_StringRequest(itemTable:getName(), L("vendorStockCurReq"), entity:getStock(uniqueID) or 0, function(text)
            text = math.Round(tonumber(text) or 0)
            EDITOR.stock(uniqueID, text)
        end)
    end):SetImage("icon16/table_edit.png")

    menu:Open()
end

function PANEL:ReloadItemList(filter)
    local entity = liaVendorEnt
    self.lines = {}
    self.items:Clear()
    for k, v in SortedPairsByMemberValue(lia.item.list, "name") do
        local itemName = v.getName and v:getName() or L(v.name)
        if filter and not itemName:lower():find(filter:lower(), 1, true) then continue end
        local mode = entity.items[k] and entity.items[k][VENDOR_MODE]
        local current, max = entity:getStock(k)
        local category = v.category or L("None")
        local panel = self.items:AddLine(itemName, self:getModeText(mode), entity:getPrice(k), max and current .. "/" .. max or "-", category)
        panel.item = k
        self.lines[k] = panel
    end
end

vgui.Register("VendorEditor", PANEL, "DFrame")
