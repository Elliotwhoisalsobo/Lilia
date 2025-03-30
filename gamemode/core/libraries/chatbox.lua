﻿lia.chat = lia.chat or {}
lia.chat.classes = lia.char.classes or {}
--[[
   Function: lia.chat.timestamp

   Description:
      Returns a formatted timestamp if ChatShowTime is enabled, adding parentheses around
      the current time. Adjusts formatting for out‑of‑character (OOC) messages.

   Parameters:
      ooc (boolean) — Whether the timestamp is for OOC chat.

   Returns:
      string — Timestamp (e.g., "(12:34)") or empty string if disabled.

   Realm:
      Shared

   Example Usage:
      print(lia.chat.timestamp(false))
]]
function lia.chat.timestamp(ooc)
    return lia.option.ChatShowTime and (ooc and " " or "") .. "(" .. lia.time.GetFormattedDate(nil, false, false, false, false, true) .. ")" .. (ooc and "" or " ") or ""
end

--[[
   Function: lia.chat.register

   Description:
      Registers a new chat class defining syntax, hearing range, send permissions, formatting,
      and optional command aliases for in‑game chat types.

   Parameters:
      chatType (string) — Unique identifier for this chat channel.
      data (table) — Configuration table with fields: prefix, desc, syntax, radius/onCanHear,
                     onCanSay, color, format, onChatAdd, filter.

   Returns:
      nil

   Realm:
      Shared

   Example Usage:
      lia.chat.register("ooc", { prefix = "/ooc", desc = "Out‑Of‑Character chat", radius = 1000 })
]]
function lia.chat.register(chatType, data)
    data.syntax = data.syntax or ""
    data.desc = data.desc or ""
    if not data.onCanHear then
        if isfunction(data.radius) then
            data.onCanHear = function(speaker, listener) return (speaker:GetPos() - listener:GetPos()):LengthSqr() <= data.radius() ^ 2 end
        elseif isnumber(data.radius) then
            local range = data.radius ^ 2
            data.onCanHear = function(speaker, listener) return (speaker:GetPos() - listener:GetPos()):LengthSqr() <= range end
        else
            data.onCanHear = function() return true end
        end
    elseif isnumber(data.onCanHear) then
        local range = data.onCanHear ^ 2
        data.onCanHear = function(speaker, listener) return (speaker:GetPos() - listener:GetPos()):LengthSqr() <= range end
    end

    data.onCanSay = data.onCanSay or function(speaker)
        if not data.deadCanChat and not speaker:Alive() then
            speaker:notifyLocalized("noPerm")
            return false
        end
        return true
    end

    data.color = data.color or Color(242, 230, 160)
    data.format = data.format or "%s: \"%s\""
    data.onChatAdd = data.onChatAdd or function(speaker, text, anonymous)
        local name = anonymous and L("someone") or hook.Run("GetDisplayedName", speaker, chatType) or IsValid(speaker) and speaker:Name() or "Console"
        chat.AddText(lia.chat.timestamp(false), data.color, string.format(data.format, name, text))
    end

    if CLIENT and data.prefix then
        local rawPrefixes = istable(data.prefix) and data.prefix or {data.prefix}
        local aliases = {}
        for _, prefix in ipairs(rawPrefixes) do
            local cmd = prefix:gsub("^/", ""):lower()
            if cmd ~= "" then table.insert(aliases, cmd) end
        end

        if #aliases > 0 then
            lia.command.add(chatType, {
                syntax = data.syntax,
                desc = data.desc,
                alias = aliases,
                onRun = function(_, args) lia.chat.parse(LocalPlayer(), table.concat(args, " ")) end
            })
        end
    end

    data.filter = data.filter or "ic"
    lia.chat.classes[chatType] = data
end

--[[
   Function: lia.chat.parse

   Description:
      Parses raw input to identify chat type and strips its prefix. Sends the message
      to the server if not flagged as noSend.

   Parameters:
      client (Player) — The sender.
      message (string) — Raw chat string.
      noSend (boolean) — If true, do not forward to server.

   Returns:
      string, string, boolean — chatType, cleaned message, anonymous flag.

   Realm:
      Shared

   Example Usage:
      local type, msg = lia.chat.parse(player, "/ooc Hello")
]]
function lia.chat.parse(client, message, noSend)
    local anonymous = false
    local chatType = "ic"
    for k, v in pairs(lia.chat.classes) do
        local isChosen = false
        local chosenPrefix = ""
        local noSpaceAfter = v.noSpaceAfter
        if istable(v.prefix) then
            for _, prefix in ipairs(v.prefix) do
                if message:sub(1, #prefix + (noSpaceAfter and 0 or 1)):lower() == (prefix .. (noSpaceAfter and "" or " ")):lower() then
                    isChosen = true
                    chosenPrefix = prefix .. (v.noSpaceAfter and "" or " ")
                    break
                end
            end
        elseif isstring(v.prefix) then
            isChosen = message:sub(1, #v.prefix + (noSpaceAfter and 0 or 1)):lower() == (v.prefix .. (v.noSpaceAfter and "" or " ")):lower()
            chosenPrefix = v.prefix .. (v.noSpaceAfter and "" or " ")
        end

        if isChosen then
            chatType = k
            message = message:sub(#chosenPrefix + 1)
            if lia.chat.classes[k].noSpaceAfter and message:sub(1, 1):match("%s") then message = message:sub(2) end
            break
        end
    end

    if not message:find("%S") then return end
    if SERVER and not noSend then lia.chat.send(client, chatType, hook.Run("PlayerMessageSend", client, chatType, message, anonymous) or message, anonymous) end
    return chatType, message, anonymous
end

if SERVER then
    --[[
       Function: lia.chat.send

       Description:
          Sends a chat message to appropriate recipients based on hearing filters.
          Honors onCanSay and onCanHear checks and optionally supports anonymous messages.

       Parameters:
          speaker (Player) — The sender.
          chatType (string) — Registered chat type.
          text (string) — Message content.
          anonymous (boolean) — Whether the sender is anonymous.
          receivers (table, optional) — Explicit recipient list.

       Returns:
          nil

       Realm:
          Shared

       Example Usage:
          lia.chat.send(player, "ooc", "Hello world!", false)
    ]]
    function lia.chat.send(speaker, chatType, text, anonymous, receivers)
        local class = lia.chat.classes[chatType]
        if class and class.onCanSay(speaker, text) ~= false then
            if class.onCanHear and not receivers then
                receivers = {}
                for _, v in player.Iterator() do
                    if v:getChar() and class.onCanHear(speaker, v) ~= false then receivers[#receivers + 1] = v end
                end

                if #receivers == 0 then return end
            end

            net.Start("cMsg")
            net.WriteString(chatType)
            net.WriteString(hook.Run("PlayerMessageSend", speaker, chatType, text, anonymous, receivers) or text)
            net.WriteBool(anonymous)
            net.Send(receivers)
        end
    end
end