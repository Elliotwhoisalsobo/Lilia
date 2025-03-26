﻿lia.command = lia.command or {}
lia.command.list = lia.command.list or {}
function lia.command.add(command, data)
    data.syntax = data.syntax or ""
    data.desc = data.desc or ""
    local superAdminOnly = data.superAdminOnly
    local adminOnly = data.adminOnly
    if not data.onRun then
        ErrorNoHalt("Command '" .. command .. "' does not have a callback, not adding!\n")
        return
    end

    if data.group then
        ErrorNoHalt("Command '" .. (data.name or command) .. "' tried to use the deprecated field 'group'!\n")
        return
    end

    if superAdminOnly or adminOnly then
        local privilegeName = "Commands - " .. (isstring(data.privilege) and data.privilege or command)
        if not CAMI.GetPrivilege(privilegeName) then
            CAMI.RegisterPrivilege({
                Name = privilegeName,
                MinAccess = superAdminOnly and "superadmin" or "admin",
                Description = data.description
            })
        end
    end

    local onRun = data.onRun
    data._onRun = data.onRun
    data.onRun = function(client, arguments)
        local hasAccess, _ = lia.command.hasAccess(client, command, data)
        if hasAccess then
            return onRun(client, arguments)
        else
            return "noPerm"
        end
    end

    local alias = data.alias
    if alias then
        if istable(alias) then
            for _, v in ipairs(alias) do
                lia.command.list[v:lower()] = data
            end
        elseif isstring(alias) then
            lia.command.list[alias:lower()] = data
        end
    end

    if command == command:lower() then
        lia.command.list[command] = data
    else
        data.realCommand = command
        lia.command.list[command:lower()] = data
    end
end

function lia.command.hasAccess(client, command, data)
    if not data then data = lia.command.list[command] end
    local privilege = data.privilege
    local superAdminOnly = data.superAdminOnly
    local adminOnly = data.adminOnly
    local accessLevels = superAdminOnly and "superadmin" or adminOnly and "admin" or "user"
    if not privilege then privilege = accessLevels == "user" and "Global" or command end
    local hasAccess = true
    if accessLevels ~= "user" then
        local privilegeName = "Commands - " .. privilege
        hasAccess = client:hasPrivilege(privilegeName)
    end

    if hook.Run("CanPlayerUseCommand", client, command) == false then hasAccess = false end
    return hasAccess, privilege
end

function lia.command.extractArgs(text)
    local skip = 0
    local arguments = {}
    local curString = ""
    for i = 1, #text do
        if i <= skip then continue end
        local c = text:sub(i, i)
        if c == "\"" then
            local match = text:sub(i):match("%b" .. c .. c)
            if match then
                curString = ""
                skip = i + #match
                arguments[#arguments + 1] = match:sub(2, -2)
            else
                curString = curString .. c
            end
        elseif c == " " and curString ~= "" then
            arguments[#arguments + 1] = curString
            curString = ""
        else
            if c == " " and curString == "" then continue end
            curString = curString .. c
        end
    end

    if curString ~= "" then arguments[#arguments + 1] = curString end
    return arguments
end

if SERVER then
    function lia.command.findPlayer(client, name)
        if isstring(name) then
            if string.find(name, "^STEAM_%d+:%d+:%d+$") then
                local player = player.GetBySteamID(name)
                if IsValid(player) then
                    return player
                else
                    client:notifyLocalized("plyNoExist")
                    return nil
                end
            elseif string.match(name, "^%d+$") and #name >= 17 then
                local sid = util.SteamIDFrom64(name)
                if sid then
                    local ply = player.GetBySteamID(sid)
                    if IsValid(ply) then return ply end
                end
            end

            if name == "^" then
                return client
            elseif name == "@" then
                local trace = client:getTracedEntity()
                if IsValid(trace) and trace:IsPlayer() then
                    return trace
                else
                    client:notifyLocalized("lookToUseAt")
                    return nil
                end
            end

            local target = lia.util.findPlayer(name) or NULL
            if IsValid(target) then
                return target
            else
                client:notifyLocalized("plyNoExist")
                return nil
            end
        else
            client:notifyLocalized("mustProvideString")
            return nil
        end
    end

    function lia.command.findFaction(client, name)
        if lia.faction.teams[name] then return lia.faction.teams[name] end
        for _, v in ipairs(lia.faction.indices) do
            if lia.util.stringMatches(L(v.name), name) then return v end
        end

        client:notifyLocalized("invalidFaction")
    end

    function lia.command.findPlayerSilent(client, name)
        local target = isstring(name) and lia.util.findPlayer(name) or NULL
        if isstring(name) and name == "@" then
            local lookingAt = client:getTracedEntity()
            if IsValid(lookingAt) and lookingAt:IsPlayer() then target = lookingAt end
        end

        if IsValid(target) then return target end
    end

    function lia.command.run(client, command, arguments)
        command = lia.command.list[command:lower()]
        if command then
            local results = {command.onRun(client, arguments or {})}
            local result = results[1]
            if isstring(result) then
                if IsValid(client) then
                    if result:sub(1, 1) == "@" then
                        client:notifyLocalized(result:sub(2), unpack(results, 2))
                    else
                        client:notify(result)
                    end
                else
                    print(result)
                end
            end
        end
    end

    function lia.command.parse(client, text, realCommand, arguments)
        if realCommand or text:utf8sub(1, 1) == "/" then
            local match = realCommand or text:lower():match("/" .. "([_%w]+)")
            if not match then
                local post = string.Explode(" ", text)
                local len = string.len(post[1])
                match = post[1]:utf8sub(2, len)
            end

            match = match:lower()
            local command = lia.command.list[match]
            if command then
                if not arguments then arguments = lia.command.extractArgs(text:sub(#match + 3)) end
                lia.command.run(client, match, arguments)
                if not realCommand then lia.log.add(client, "command", text) end
            else
                if IsValid(client) then
                    client:notifyLocalized("cmdNoExist")
                else
                    LiliaInformation("Sorry, that command does not exist.")
                end
            end
            return true
        end
        return false
    end
else
    function lia.command.send(command, ...)
        netstream.Start("cmd", command, {...})
    end
end

hook.Add("BuildInformationMenu", "BuildInformationMenuCommands", function(pages)
    local client = LocalPlayer()
    table.insert(pages, {
        name = "Commands",
        drawFunc = function(panel)
            local char = client:getChar()
            if not char then
                panel:Add("DLabel"):SetText("No character found!"):Dock(TOP)
                return
            end

            local scroll = vgui.Create("DScrollPanel", panel)
            scroll:Dock(FILL)
            local iconLayout = vgui.Create("DIconLayout", scroll)
            iconLayout:Dock(FILL)
            iconLayout:SetSpaceY(5)
            iconLayout:SetSpaceX(5)
            iconLayout.PerformLayout = function(self)
                local y = 0
                local parentWidth = self:GetWide()
                for _, child in ipairs(self:GetChildren()) do
                    child:SetPos((parentWidth - child:GetWide()) / 2, y)
                    y = y + child:GetTall() + self:GetSpaceY()
                end

                self:SetTall(y)
            end

            for cmdName, cmdData in SortedPairs(lia.command.list) do
                if isnumber(cmdName) then continue end
                local hasAccess, privilege = lia.command.hasAccess(client, cmdName, cmdData)
                if hasAccess then
                    local hasDesc = cmdData.desc and cmdData.desc ~= ""
                    local panelHeight = hasDesc and 80 or 40
                    local commandPanel = vgui.Create("DPanel", iconLayout)
                    commandPanel:SetSize(panel:GetWide(), panelHeight)
                    commandPanel.Paint = function(_, w, h)
                        draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200))
                        local baseX = 20
                        local commandText = "/" .. cmdName
                        local syntax = cmdData.syntax or ""
                        if syntax ~= "" then
                            if syntax:sub(1, 1) == "" and syntax:sub(-1) == "" then
                                commandText = commandText .. " " .. syntax
                            else
                                commandText = commandText .. " " .. syntax .. ""
                            end
                        end

                        if hasDesc then
                            draw.SimpleText(commandText, "liaMediumFont", baseX, 5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                            draw.SimpleText(cmdData.desc, "liaSmallFont", baseX, 45, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                            draw.SimpleText(privilege or "None", "liaSmallFont", w - 20, 45, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
                        else
                            draw.SimpleText(commandText, "liaMediumFont", baseX, h / 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                            draw.SimpleText(privilege or "None", "liaSmallFont", w - 20, h / 2, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                        end
                    end
                end
            end
        end
    })
end)