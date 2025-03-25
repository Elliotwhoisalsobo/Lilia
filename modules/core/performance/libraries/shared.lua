﻿local serverCommands = {"mp_show_voice_icons 0", "net_maxfilesize 64", "sv_kickerrornum 0", "sv_allowupload 0", "sv_allowdownload 0", "sv_allowcslua 0", "gmod_physiterations 4", "sbox_noclip 0"}
local clientCommands = {"mp_show_voice_icons 0", "gmod_mcore_test 1", "mem_max_heapsize 131072", "mem_max_heapsize_dedicated 131072", "mem_min_heapsize 131072", "threadpool_affinity 64", "mat_queue_mode 2", "mat_powersavingsmode 0", "r_queued_ropes 1", "r_threaded_renderables 1", "r_threaded_particles 1", "r_threaded_client_shadow_manager 1", "cl_threaded_client_leaf_system 1", "cl_threaded_bone_setup 1", "cl_forcepreload 1", "cl_lagcompensation 1", "cl_timeout 3600", "cl_smoothtime 0.05", "cl_localnetworkbackdoor 1", "cl_cmdrate 66", "cl_updaterate 66", "cl_interp_ratio 2", "studio_queue_mode 1", "ai_expression_optimization 1", "filesystem_max_stdio_read 64", "in_usekeyboardsampletime 1", "r_radiosity 4", "rate 1048576", "mat_frame_sync_enable 0", "mat_framebuffercopyoverlaysize 0", "mat_managedtextures 0", "fast_fogvolume 1", "lod_TransitionDist 2000", "filesystem_unbuffered_io 0"}
local serverHooks = {{"OnEntityCreated", "WidgetInit"}, {"Think", "DOFThink"}, {"Think", "CheckSchedules"}, {"PlayerTick", "TickWidgets"}, {"PlayerInitialSpawn", "PlayerAuthSpawn"}, {"LoadGModSave", "LoadGModSave"}}
local clientHooks = {{"HUDPaint", "DamageEffect"}, {"StartChat", "StartChatIndicator"}, {"FinishChat", "EndChatIndicator"}, {"PostDrawEffects", "RenderWidgets"}, {"PostDrawEffects", "RenderHalos"}, {"OnEntityCreated", "WidgetInit"}, {"GUIMousePressed", "SuperDOFMouseDown"}, {"GUIMouseReleased", "SuperDOFMouseUp"}, {"PreventScreenClicks", "SuperDOFPreventClicks"}, {"Think", "DOFThink"}, {"Think", "CheckSchedules"}, {"NeedsDepthPass", "NeedsDepthPass_Bokeh"}, {"RenderScene", "RenderSuperDoF"}, {"RenderScene", "RenderStereoscopy"}, {"PreRender", "PreRenderFrameBlend"}, {"PostRender", "RenderFrameBlend"}, {"RenderScreenspaceEffects", "RenderBokeh"}}
local function ExecuteCommands(IsServer)
    if IsServer then
        for _, cmd in ipairs(serverCommands) do
            game.ConsoleCommand(cmd .. "\n")
        end
    else
        for _, cmd in ipairs(clientCommands) do
            local command, args = cmd:match("^(%S+)%s+(.*)$")
            if command then
                if args then
                    local argList = {}
                    for arg in string.gmatch(args, "%S+") do
                        table.insert(argList, arg)
                    end

                    RunConsoleCommand(command, unpack(argList))
                else
                    RunConsoleCommand(command)
                end
            end
        end
    end
end

local function RemoveHooks(IsServer)
    if IsServer then
        for _, hookData in ipairs(serverHooks) do
            hook.Remove(hookData[1], hookData[2])
        end
    else
        for _, hookData in ipairs(clientHooks) do
            hook.Remove(hookData[1], hookData[2])
        end
    end
end

function MODULE:Initialize()
    ExecuteCommands(SERVER)
end

function MODULE:OnReloaded()
    RemoveHooks(SERVER)
    ExecuteCommands(SERVER)
end

function widgets.PlayerTick()
end
