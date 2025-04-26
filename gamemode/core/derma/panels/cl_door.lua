﻿local PANEL = {}
function PANEL:Init()
    self:SetSize(280, 240)
    self:SetTitle(L("doorSettings"))
    self:Center()
    self:MakePopup()
    self.access = self:Add("DListView")
    self.access:Dock(FILL)
    self.access:AddColumn(L("doorName")).Header:SetTextColor(Color(25, 25, 25))
    self.access:AddColumn(L("doorAccess")).Header:SetTextColor(Color(25, 25, 25))
    self.access.OnClickLine = function(_, line)
        if IsValid(line.player) then
            local menu = DermaMenu()
            menu:AddOption(L("doorTenant"), function() if self.accessData and self.accessData[line.player] ~= DOOR_TENANT then netstream.Start("doorPerm", self.door, line.player, DOOR_TENANT) end end):SetImage("icon16/user_add.png")
            menu:AddOption(L("doorGuest"), function() if self.accessData and self.accessData[line.player] ~= DOOR_GUEST then netstream.Start("doorPerm", self.door, line.player, DOOR_GUEST) end end):SetImage("icon16/user_green.png")
            menu:AddOption(L("doorNone"), function() if self.accessData and self.accessData[line.player] ~= DOOR_NONE then netstream.Start("doorPerm", self.door, line.player, DOOR_NONE) end end):SetImage("icon16/user_red.png")
            menu:Open()
        end
    end
end

function PANEL:setDoor(door, access, door2)
    local client = LocalPlayer()
    door.liaPanel = self
    self.accessData = access
    self.door = door
    for _, v in player.Iterator() do
        if v ~= client and v:getChar() then self.access:AddLine(v:Name():gsub("#", "\226\128\139#"), L(ACCESS_LABELS[access[v] or 0])).player = v end
    end

    if self:checkAccess(DOOR_OWNER) then
        self.sell = self:Add("DButton")
        self.sell:Dock(BOTTOM)
        self.sell:SetText(L("doorSell"))
        self.sell:SetTextColor(color_white)
        self.sell:DockMargin(0, 5, 0, 0)
        self.sell.DoClick = function()
            self:Remove()
            lia.command.send("doorsell")
        end
    end

    if self:checkAccess(DOOR_TENANT) then
        self.name = self:Add("DTextEntry")
        self.name:Dock(TOP)
        self.name:DockMargin(0, 0, 0, 5)
        self.name.Think = function(this)
            if not this:IsEditing() then
                local entity = IsValid(door2) and door2 or door
                self.name:SetText(entity:getNetVar("title", L("doorTitleOwned")))
            end
        end

        self.name.OnEnter = function(this) lia.command.send("doorsettitle", this:GetText()) end
    end
end

function PANEL:checkAccess(access)
    local client = LocalPlayer()
    access = access or DOOR_GUEST
    if (self.accessData[client] or 0) >= access then return true end
    return false
end

function PANEL:Think()
    if self.accessData and not IsValid(self.door) and self:checkAccess() then self:Remove() end
end

vgui.Register("liaDoorMenu", PANEL, "DFrame")
