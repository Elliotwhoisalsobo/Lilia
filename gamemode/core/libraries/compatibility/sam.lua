hook.Add("InitializedModules", "SAM_InitializedModules", function()
    for _, commandInfo in ipairs(sam.command.get_commands()) do
        local customSyntax = ""
        for _, argInfo in ipairs(commandInfo.args) do
            customSyntax = customSyntax == "" and "[" or customSyntax .. " ["
            customSyntax = customSyntax .. (argInfo.default and tostring(type(argInfo.default)) or "string") .. " "
            customSyntax = customSyntax .. argInfo.name .. "]"
        end

        if lia.command.list[commandInfo.name] then continue end
        lia.command.add(commandInfo.name, {
            desc = commandInfo.help,
            adminOnly = commandInfo.default_rank == "admin",
            superAdminOnly = commandInfo.default_rank == "superadmin",
            syntax = customSyntax,
            onRun = function(_, arguments) RunConsoleCommand("sam", commandInfo.name, unpack(arguments)) end
        })
    end
end)

hook.Add("SAM.CanRunCommand", "Check4Staff", function(client, _, _, cmd)
    if type(client) ~= "Player" then return true end
    if lia.config.get("SAMEnforceStaff", false) then
        if cmd.permission and not client:HasPermission(cmd.permission) then
            client:notifyLocalized("staffPermissionDenied")
            return false
        end

        if client:hasPrivilege(client, "Staff Permissions - Can Bypass Staff Faction SAM Command whitelist", nil) or client:isStaffOnDuty() then
            return true
        else
            client:notifyLocalized("staffRestrictedCommand")
            return false
        end
    end
end)

if SERVER then
    sam.command.new("blind"):SetPermission("blind", "superadmin"):AddArg("player"):Help("Blinds the Players"):OnExecute(function(client, targets)
        for i = 1, #targets do
            local target = targets[i]
            net.Start("sam_blind")
            net.WriteBool(true)
            net.Send(target)
        end

        if not sam.is_command_silent then
            client:sam_send_message("{A} Blinded {T}", {
                A = client,
                T = targets
            })
        end
    end):End()

    sam.command.new("unblind"):SetPermission("blind", "superadmin"):AddArg("player"):Help("Unblinds the Players"):OnExecute(function(client, targets)
        for i = 1, #targets do
            local target = targets[i]
            net.Start("sam_blind")
            net.WriteBool(false)
            net.Send(target)
        end

        if not sam.is_command_silent then
            client:sam_send_message("{A} Un-Blinded {T}", {
                A = client,
                T = targets
            })
        end
    end):End()

    hook.Add("InitializedModules", "SAM_InitializedModules", function() hook.Remove("PlayerSay", "SAM.Chat.Asay") end)
else
    net.Receive("sam_blind", function()
        local enabled = net.ReadBool()
        if enabled then
            hook.Add("HUDPaint", "sam_blind", function() draw.RoundedBox(0, 0, 0, ScrW(), ScrH(), Color(0, 0, 0, 255)) end)
        else
            hook.Remove("HUDPaint", "sam_blind")
        end
    end)
end

local function CanReadNotifications(client)
    if not lia.config.get("DisplayStaffCommands") then return false end
    if not lia.config.get("AdminOnlyNotification") then return true end
    return client:hasPrivilege("Staff Permissions - Can See SAM Notifications") or client:isStaffOnDuty()
end

function sam.player.send_message(client, msg, tbl)
    if SERVER then
        if sam.isconsole(client) then
            local result = sam.format_message(msg, tbl)
            sam.print(unpack(result, 1, result.__cnt))
        elseif client then
            return sam.netstream.Start(client, "send_message", msg, tbl)
        end
    else
        if client and CanReadNotifications(client) then
            local prefix_result = sam.format_message(sam.config.get("ChatPrefix", ""))
            local prefix_n = #prefix_result
            local result = sam.format_message(msg, tbl, prefix_result, prefix_n)
            chat.AddText(unpack(result, 1, result.__cnt))
        end
    end
end

lia.command.add("cleardecals", {
    adminOnly = true,
    privilege = "Clear Decals",
    desc = "Clears all decals (blood, bullet holes, etc.) for every player.",
    onRun = function()
        for _, v in player.Iterator() do
            v:ConCommand("r_cleardecals")
        end
    end
})

lia.command.add("playtime", {
    adminOnly = false,
    privilege = "View Own Playtime",
    desc = "Displays your total playtime on the server.",
    onRun = function(client)
        local steamID = client:SteamID64()
        local query = "SELECT play_time FROM sam_players WHERE steamid = " .. SQLStr(steamID) .. ";"
        local result = sql.QueryRow(query)
        if result then
            local playTimeInSeconds = tonumber(result.play_time) or 0
            local hours = math.floor(playTimeInSeconds / 3600)
            local minutes = math.floor((playTimeInSeconds % 3600) / 60)
            local seconds = playTimeInSeconds % 60
            client:ChatPrint(L("playtimeYour", hours, minutes, seconds))
        else
            client:ChatPrint(L("playtimeError"))
        end
    end
})

lia.command.add("plygetplaytime", {
    adminOnly = true,
    privilege = "View Playtime",
    desc = "Shows the total playtime of the specified character.",
    syntax = "[string charname]",
    AdminStick = {
        Name = L("adminStickGetPlayTimeName"),
        Category = L("Moderation Tools"),
        SubCategory = L("misc"),
        Icon = "icon16/time.png"
    },
    onRun = function(client, arguments)
        local targetName = arguments[1]
        if not targetName then
            client:notifyLocalized("specifyPlayer")
            return
        end

        local target = lia.util.findPlayer(client, targetName)
        if not target or not IsValid(target) then
            client:notifyLocalized("targetNotFound")
            return
        end

        local playTimeInSeconds = target:sam_get_play_time()
        local hours = math.floor(playTimeInSeconds / 3600)
        local minutes = math.floor((playTimeInSeconds % 3600) / 60)
        local seconds = playTimeInSeconds % 60
        client:ChatPrint(L("playtimeFor", target:Nick(), hours, minutes, seconds))
    end
})

CAMI.RegisterPrivilege({
    Name = "Staff Permissions - Can See SAM Notifications Outside Staff Character",
    MinAccess = "superadmin",
    Description = "Allows access to Seeing SAM Notifications Outside Staff Character."
})

CAMI.RegisterPrivilege({
    Name = "Staff Permissions - Can Bypass Staff Faction SAM Command whitelist",
    MinAccess = "superadmin",
    Description = "Allows staff to bypass the SAM command whitelist for the Staff Faction."
})

lia.config.add("DisplayStaffCommands", "Display Staff Commands", true, nil, {
    desc = "Controls whether notifications and commands for staff are displayed.",
    category = "Staff",
    type = "Boolean"
})

lia.config.add("AdminOnlyNotification", "Admin Only Notifications", true, nil, {
    desc = "Restricts certain notifications to admins with specific permissions or those on duty.",
    category = "Staff",
    type = "Boolean"
})

lia.config.add("SAMEnforceStaff", "Enforce Staff Rank To SAM", true, nil, {
    desc = "Determines whether staff enforcement for SAM commands is enabled",
    category = "Staff",
    type = "Boolean"
})