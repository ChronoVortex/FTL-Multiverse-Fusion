-------------
-- IMPORTS --
-------------
local weaponInfo = mods.fusion.weaponInfo
local droneInfo = mods.fusion.droneInfo
local customTagsAll = mods.fusion.customTagsAll
local customTagsWeapons = mods.fusion.customTagsWeapons
local customTagsDrones = mods.fusion.customTagsDrones
local Children = mods.fusion.Children
local parse_xml_bool = mods.fusion.parse_xml_bool
local tag_add_all = mods.fusion.tag_add_all
local tag_add_weapons = mods.fusion.tag_add_weapons
local tag_add_drones = mods.fusion.tag_add_drones

--IMPORT LOGIC FUNCTIONS HERE eg. vter

------------
-- PARSER --
------------
local function parser(node)
    local example = {}
    
    if not node:first_attribute("number") then error("example tag requires a number!") end
    example.number = tonumber(node:first_attribute("number"):value())
    if not hack.number then error("Invalid number for example 'number' attribute!") end

    if node:first_attribute("string") then
        example.string = node:first_attribute("string"):value()
        if not example.string then
            error("Invalid example 'string' attribute!")
        end
    end
    
    return example
end

-----------
-- LOGIC --
-----------
local function logic()
    -- Run every tick
    script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
        
    end)

    -- Track when the weapon with the tag fires
    script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
        if weaponInfo[weapon.blueprint.name]["fus-example"] then
            
        end
    end)

    -- Track when the weapon with the tag is a beam and hits the enemy
    script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
        local example = weaponInfo[projectile.extend.name]["fus-example"]
        if example and example.amount and example.amount > 0 and beamHitType == Defines.BeamHit.NEW_ROOM then
            
        end
        return Defines.Chain.CONTINUE, beamHitType
    end)

    -- Track when the weapon with the tag is not a beam and hits the enemy
    script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
        local example = nil
        pcall(function() example = weaponInfo[projectile.extend.name]["fus-example"] end)
        if example and example.amount and hack.amount > 0 then

        end
    end)

    -- Track when the weapon with the tag and hits the enemy shield
    script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION, function(shipManager, projectile, damage, response)
        local example = nil
        pcall(function() example = weaponInfo[projectile.extend.name]["fus-example"] end)
        if example and example.amount and example.amount > 0 then

        end
    end)
end

tag_add_weapons("fus-example", parser, logic)
