﻿lia.command.add("pktoggle", {
    adminOnly = true,
    privilege = "Toggle Permakill",
    desc = "Toggles a character’s permanent kill flag (marks or unmarks them for permanent death).",
    syntax = "[string charname]",
    AdminStick = {
        Name = "Toggle Character Killing (Ban)",
        Category = "Character Management",
        SubCategory = "Bans",
        Icon = "icon16/user_delete.png"
    },
    onRun = function(client, arguments)
        local target = lia.util.findPlayer(client, arguments[1])
        if not target or not IsValid(target) then
            client:notifyLocalized("targetNotFound")
            return
        end

        local character = target:getChar()
        if not character then
            client:notifyLocalized("invalid", "Character")
            return
        end

        local currentState = character:getData("PermaKillFlagged", false)
        local newState = not currentState
        character:setData("PermaKillFlagged", newState)
        if newState then
            client:notifyLocalized("pktoggle_true")
        else
            client:notifyLocalized("pktoggle_false")
        end
    end
})
