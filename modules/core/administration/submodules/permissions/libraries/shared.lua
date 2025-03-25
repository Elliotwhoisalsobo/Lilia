﻿function MODULE:InitializedModules()
    local defaultUserTools = {
        adv_duplicator = true,
        duplicator = true,
        advdupe2 = true,
        remover = true,
    }

    if properties.List then
        for name in pairs(properties.List) do
            if name ~= "persist" and name ~= "drive" and name ~= "bonemanipulate" then
                local privilege = "Staff Permissions - Access Property " .. name:gsub("^%l", string.upper)
                if not CAMI.GetPrivilege(privilege) then
                    CAMI.RegisterPrivilege({
                        Name = privilege,
                        MinAccess = "admin",
                        Description = "Allows access to Entity Property " .. name:gsub("^%l", string.upper)
                    })
                end
            end
        end
    end

    for _, wep in ipairs(weapons.GetList()) do
        if wep.ClassName == "gmod_tool" and wep.Tool then
            for tool in pairs(wep.Tool) do
                local privilege = "Staff Permissions - Access Tool " .. tool:gsub("^%l", string.upper)
                if not CAMI.GetPrivilege(privilege) then
                    CAMI.RegisterPrivilege({
                        Name = privilege,
                        MinAccess = defaultUserTools[string.lower(tool)] and "user" or "admin",
                        Description = "Allows access to " .. tool:gsub("^%l", string.upper)
                    })
                end
            end
        end
    end
end

concommand.Add("list_entities", function(client)
    local entityCount = {}
    local totalEntities = 0
    if not IsValid(client) then
        LiliaInformation("Entities on the server:")
        for _, entity in ents.Iterator() do
            local className = entity:GetClass() or "Unknown"
            entityCount[className] = (entityCount[className] or 0) + 1
            totalEntities = totalEntities + 1
        end

        for className, count in pairs(entityCount) do
            LiliaInformation(string.format("Class: %s | Count: %d", className, count))
        end

        LiliaInformation("Total entities on the server: " .. totalEntities)
    end
end)

lia.flag.add("p", "Access to the physgun.", function(client, isGiven)
    if isGiven then
        client:Give("weapon_physgun")
        client:SelectWeapon("weapon_physgun")
    else
        client:StripWeapon("weapon_physgun")
    end
end)

lia.flag.add("t", "Access to the toolgun", function(client, isGiven)
    if isGiven then
        client:Give("gmod_tool")
        client:SelectWeapon("gmod_tool")
    else
        client:StripWeapon("gmod_tool")
    end
end)

lia.flag.add("C", "Access to spawn vehicles.")
lia.flag.add("z", "Access to spawn SWEPS.")
lia.flag.add("E", "Access to spawn SENTs.")
lia.flag.add("L", "Access to spawn Effects.")
lia.flag.add("r", "Access to spawn ragdolls.")
lia.flag.add("e", "Access to spawn props.")
lia.flag.add("n", "Access to spawn NPCs.")
