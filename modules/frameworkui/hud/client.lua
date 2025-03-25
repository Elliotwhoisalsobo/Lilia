﻿local MODULE = MODULE
local ScrW, ScrH = ScrW, ScrH
local RealTime, FrameTime = RealTime, FrameTime
local mathApproach = math.Approach
local IsValid = IsValid
local toScreen = FindMetaTable("Vector").ToScreen
local paintedEntitiesCache, lastTrace, charInfo, lastEntity = {}, {}, {}, nil
local blurGoal, blurValue, nextUpdate = 0, 0, 0
local vignetteAlphaGoal, vignetteAlphaDelta = 0, 0
local NoDrawCrosshairWeapon = {"weapon_crowbar", "weapon_stunstick", "weapon_bugbait"}
local healthPercent = {
    [0.2] = {"Critical Condition", Color(192, 57, 43)},
    [0.4] = {"Serious Injury", Color(231, 76, 60)},
    [0.6] = {"Moderate Injury", Color(255, 152, 0)},
    [0.8] = {"Minor Injury", Color(255, 193, 7)},
    [1.0] = {"Healthy", Color(46, 204, 113)}
}

local hasVignetteMaterial = lia.util.getMaterial("lilia/gui/vignette.png") ~= "___error"
local function canDrawAmmo(wpn)
    if IsValid(wpn) and wpn.DrawAmmo ~= false and lia.config.get("AmmoDrawEnabled", false) then return true end
end

local function drawAmmo(wpn)
    local client = LocalPlayer()
    if not IsValid(wpn) then return end
    local clip = wpn:Clip1()
    local count = client:GetAmmoCount(wpn:GetPrimaryAmmoType())
    local sec = client:GetAmmoCount(wpn:GetSecondaryAmmoType())
    local x, y = ScrW() - 80, ScrH() - 80
    if sec > 0 then
        lia.util.drawBlurAt(x, y, 64, 64)
        surface.SetDrawColor(255, 255, 255, 5)
        surface.DrawRect(x, y, 64, 64)
        surface.SetDrawColor(255, 255, 255, 3)
        surface.DrawOutlinedRect(x, y, 64, 64)
        lia.util.drawText(sec, x + 32, y + 32, nil, 1, 1, "liaBigFont")
    end

    if wpn:GetClass() ~= "weapon_slam" and (clip > 0 or count > 0) then
        x = x - (sec > 0 and 144 or 64)
        lia.util.drawBlurAt(x, y, 128, 64)
        surface.SetDrawColor(255, 255, 255, 5)
        surface.DrawRect(x, y, 128, 64)
        surface.SetDrawColor(255, 255, 255, 3)
        surface.DrawOutlinedRect(x, y, 128, 64)
        lia.util.drawText(clip == -1 and count or clip .. "/" .. count, x + 64, y + 32, nil, 1, 1, "liaBigFont")
    end
end

local function canDrawCrosshair()
    local client = LocalPlayer()
    local rag = Entity(client:getLocalVar("ragdoll", 0))
    local wpn = client:GetActiveWeapon()
    if not client:getChar() then return false end
    if IsValid(wpn) then
        local cl = wpn:GetClass()
        if cl == "gmod_tool" or string.find(cl, "lia_") or string.find(cl, "detector_") then return true end
        if not NoDrawCrosshairWeapon[cl] and lia.config.get("CrosshairEnabled", true) and client:Alive() and client:getChar() and not IsValid(rag) and wpn and not (g_ContextMenu:IsVisible() or IsValid(lia.gui.character) and lia.gui.character:IsVisible()) then return true end
    end
end

local function drawCrosshair()
    local client = LocalPlayer()
    local t = util.QuickTrace(client:GetShootPos(), client:GetAimVector() * 15000, client)
    if t.HitPos then
        local p = t.HitPos:ToScreen()
        local s = 3
        if p then
            p[1] = math.Round(p[1] or 0)
            p[2] = math.Round(p[2] or 0)
            draw.RoundedBox(0, p[1] - s / 2, p[2] - s / 2, s, s, color_white)
            s = s - 2
            draw.RoundedBox(0, p[1] - s / 2, p[2] - s / 2, s, s, color_white)
        end
    end
end

local function canDrawWatermark()
    local hookResult = hook.Run("ShouldDrawWatermark")
    if hookResult ~= nil then return hookResult end

    return lia.config.get("WatermarkEnabled", false) and isstring(lia.config.get("GamemodeVersion", "")) and lia.config.get("GamemodeVersion", "") ~= "" and isstring(lia.config.get("WatermarkLogo", "")) and lia.config.get("WatermarkLogo", "") ~= ""
end

local function drawWatermark()
    local w, h = 64, 64
    local logoPath = lia.config.get("WatermarkLogo", "")
    local ver = tostring(lia.config.get("GamemodeVersion", ""))
    if logoPath ~= "" then
        local logo = lia.util.getMaterial(logoPath, "smooth")
        surface.SetMaterial(logo)
        surface.SetDrawColor(255, 255, 255, 80)
        surface.DrawTexturedRect(5, ScrH() - h - 5, w, h)
    end

    if ver ~= "" then
        surface.SetFont("liaHugeFont")
        local _, ty = surface.GetTextSize(ver)
        surface.SetTextColor(255, 255, 255, 80)
        surface.SetTextPos(15 + w, ScrH() - h / 2 - ty / 2)
        surface.DrawText(ver)
    end
end

local function DrawFPS()
    local f = math.Round(1 / FrameTime())
    local minF = MODULE.minFPS or 60
    local maxF = MODULE.maxFPS or 100
    MODULE.barH = MODULE.barH or 1
    MODULE.barH = mathApproach(MODULE.barH, f / maxF * 100, 0.5)
    if f > maxF then MODULE.maxFPS = f end
    if f < minF then MODULE.minFPS = f end
    draw.SimpleText(f .. " FPS", "liaMediumFont", ScrW() - 10, ScrH() / 2 + 20, Color(255, 255, 255), TEXT_ALIGN_RIGHT, 1)
    draw.RoundedBox(0, ScrW() - 30, ScrH() / 2 - MODULE.barH, 20, MODULE.barH, Color(255, 255, 255))
    draw.SimpleText("Max : " .. (MODULE.maxFPS or maxF), "liaMediumFont", ScrW() - 10, ScrH() / 2 + 40, Color(150, 255, 150), TEXT_ALIGN_RIGHT, 1)
    draw.SimpleText("Min : " .. (MODULE.minFPS or minF), "liaMediumFont", ScrW() - 10, ScrH() / 2 + 55, Color(255, 150, 150), TEXT_ALIGN_RIGHT, 1)
end

local function DrawVignette()
    if hasVignetteMaterial then
        local ft = FrameTime()
        local w, h = ScrW(), ScrH()
        vignetteAlphaDelta = mathApproach(vignetteAlphaDelta, vignetteAlphaGoal, ft * 30)
        surface.SetDrawColor(0, 0, 0, 175 + vignetteAlphaDelta)
        surface.SetMaterial(lia.util.getMaterial("lilia/gui/vignette.png"))
        surface.DrawTexturedRect(0, 0, w, h)
    end
end

local function DrawBlur()
    local client = LocalPlayer()
    blurGoal = client:getLocalVar("blur", 0) + (hook.Run("AdjustBlurAmount", blurGoal) or 0)
    if blurValue ~= blurGoal then blurValue = mathApproach(blurValue, blurGoal, FrameTime() * 20) end
    if blurValue > 0 and not client:ShouldDrawLocalPlayer() then lia.util.drawBlurAt(0, 0, ScrW(), ScrH(), blurValue) end
end

local function ShouldDrawBlur()
    local hookResult = hook.Run("ShouldDrawBlur")
    if hookResult ~= nil then return hookResult end

    return LocalPlayer():Alive()
end

local function RenderEntities()
    local client = LocalPlayer()
    if client.getChar and client:getChar() then
        local ft = FrameTime()
        local rt = RealTime()
        if nextUpdate < rt then
            nextUpdate = rt + 0.5
            lastTrace.start = client:GetShootPos()
            lastTrace.endpos = lastTrace.start + client:GetAimVector() * 160
            lastTrace.filter = client
            lastTrace.mins = Vector(-4, -4, -4)
            lastTrace.maxs = Vector(4, 4, 4)
            lastTrace.mask = MASK_SHOT_HULL
            lastEntity = util.TraceHull(lastTrace).Entity
            if IsValid(lastEntity) and hook.Run("ShouldDrawEntityInfo", lastEntity) then paintedEntitiesCache[lastEntity] = true end
        end

        for ent, drawing in pairs(paintedEntitiesCache) do
            if IsValid(ent) then
                local goal = drawing and 255 or 0
                local a = mathApproach(ent.liaAlpha or 0, goal, ft * 1000)
                if lastEntity ~= ent then paintedEntitiesCache[ent] = false end
                if a > 0 then
                    local pl = ent.getNetVar and ent:getNetVar("player")
                    if IsValid(pl) then
                        local p = toScreen(ent:LocalToWorld(ent:OBBCenter()))
                        hook.Run("DrawEntityInfo", pl, a, p)
                    elseif ent.onDrawEntityInfo then
                        ent.onDrawEntityInfo(ent, a)
                    else
                        hook.Run("DrawEntityInfo", ent, a)
                    end
                end

                ent.liaAlpha = a
                if a == 0 and goal == 0 then paintedEntitiesCache[ent] = nil end
            else
                paintedEntitiesCache[ent] = nil
            end
        end
    end
end

function MODULE:ShouldDrawEntityInfo(e)
    if IsValid(e) then
        if e:IsPlayer() and e:getChar() then
            if e:isNoClipping() then return false end
            if e:GetNoDraw() then return false end
            return true
        end

        if IsValid(e.getNetVar and e:getNetVar("player")) then return e == LocalPlayer() and not LocalPlayer():ShouldDrawLocalPlayer() end
        if e.DrawEntityInfo then return true end
        if e.onShouldDrawEntityInfo then return e:onShouldDrawEntityInfo() end
        return true
    end
    return false
end

function MODULE:GetInjuredText(c)
    local h = c:Health()
    local mh = c:GetMaxHealth() or 100
    local p = h / mh
    local r = nil
    for threshold, data in pairs(healthPercent) do
        if p <= threshold then
            r = data
            break
        end
    end

    if not r then r = healthPercent[1.0] end
    return r
end

function MODULE:DrawCharInfo(c, _, info)
    local injuredText = hook.Run("GetInjuredText", c)
    if injuredText then
        local text, col = injuredText[1], injuredText[2]
        if text and col then info[#info + 1] = {L(text), col} end
    end
end

function MODULE:DrawEntityInfo(e, a, pos)
    if not e.IsPlayer(e) then return end
    if hook.Run("ShouldDrawPlayerInfo", e) == false then return end
    local ch = e.getChar(e)
    if not ch then return end
    pos = pos or toScreen(e.GetPos(e) + (e.Crouching(e) and Vector(0, 0, 48) or Vector(0, 0, 80)))
    local x, y = pos.x, pos.y
    charInfo = {}
    if e.widthCache ~= lia.config.get("descriptionWidth", 0.5) then
        e.widthCache = lia.config.get("descriptionWidth", 0.5)
        e.liaNameCache, e.liaDescCache = nil, nil
    end

    e.liaNameCache = nil
    e.liaDescCache = nil
    local name = hook.Run("GetDisplayedName", e, nil) or ch.getName(ch)
    if name ~= e.liaNameCache then
        e.liaNameCache = name
        if #name > 250 then name = name:sub(1, 250) .. "..." end
        e.liaNameLines = lia.util.wrapText(name, ScrW() * e.widthCache, "liaSmallFont")
    end

    for i = 1, #e.liaNameLines do
        charInfo[#charInfo + 1] = {e.liaNameLines[i], color_white}
    end

    local desc = hook.Run("GetDisplayedDescription", e, true) or ch.getDesc(ch)
    if desc ~= e.liaDescCache then
        e.liaDescCache = desc
        if #desc > 250 then desc = desc:sub(1, 250) .. "..." end
        e.liaDescLines = lia.util.wrapText(desc, ScrW() * e.widthCache, "liaSmallFont")
    end

    for i = 1, #e.liaDescLines do
        charInfo[#charInfo + 1] = {e.liaDescLines[i]}
    end

    hook.Run("DrawCharInfo", e, ch, charInfo)
    for i = 1, #charInfo do
        local info = charInfo[i]
        local _, ty = lia.util.drawText(info[1]:gsub("#", "\226\128\139#"), x, y, ColorAlpha(info[2] or color_white, a), 1, 1, "liaSmallFont")
        y = y + ty
    end
end

function MODULE:HUDPaint()
    local client = LocalPlayer()
    if client:Alive() and client:getChar() then
        local wpn = client:GetActiveWeapon()
        if canDrawAmmo(wpn) then drawAmmo(wpn) end
        if canDrawCrosshair() then drawCrosshair() end
        if lia.option.get("fpsDraw", false) then DrawFPS() end
        if lia.config.get("Vignette", true) then DrawVignette() end
        if canDrawWatermark() then drawWatermark() end
    end
end

function MODULE:HUDPaintBackground()
    if not is64Bits() then draw.SimpleText("We recommend the use of the x86-64 Garry's Mod Branch for this server, consider swapping as soon as possible.", "liaSmallFont", ScrW() * 0.5, ScrH() * 0.97, Color(255, 255, 255, 10), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end
    if ShouldDrawBlur() then DrawBlur() end
    RenderEntities()
end

function MODULE:TooltipInitialize(var, panel)
    if panel.liaToolTip or panel.itemID then
        var.markupObject = lia.markup.parse(var:GetText(), ScrW() * 0.15)
        var:SetText("")
        var:SetWide(math.max(ScrW() * 0.15, 200) + 12)
        var:SetHeight(var.markupObject:getHeight() + 12)
        var:SetAlpha(0)
        var:AlphaTo(255, 0.2, 0)
        var.isItemTooltip = true
    end
end

function MODULE:TooltipPaint(var, w, h)
    if var.isItemTooltip then
        lia.util.drawBlur(var, 2, 2)
        surface.SetDrawColor(0, 0, 0, 230)
        surface.DrawRect(0, 0, w, h)
        if var.markupObject then var.markupObject:draw(6, 8) end
        return true
    end
end

function MODULE:TooltipLayout(var)
    if var.isItemTooltip then return true end
end

lia.bar.add(function()
    local client = LocalPlayer()
    return client:Health() / client:GetMaxHealth()
end, Color(200, 50, 40), nil, "health")

lia.bar.add(function()
    local client = LocalPlayer()
    return math.min(client:Armor() / 100, 1)
end, Color(30, 70, 180), nil, "armor")

timer.Create("liaVignetteChecker", 1, 0, function()
    local client = LocalPlayer()
    if IsValid(client) then
        local d = {}
        d.start = client:GetPos()
        d.endpos = d.start + Vector(0, 0, 768)
        d.filter = client
        local tr = util.TraceLine(d)
        if tr and tr.Hit then
            vignetteAlphaGoal = 80
        else
            vignetteAlphaGoal = 0
        end
    end
end)
