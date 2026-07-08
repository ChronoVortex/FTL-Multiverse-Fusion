local vter = mods.fusion.vter
local real_projectile = mods.fusion.real_projectile
local randomInt = mods.fusion.randomInt
local fusion = mods.fusion

local COOLDOWN_AUGS = {
  [fusion.system_ids.SYS_TELEPORTER] = "FAST_TELEPORT",
  [fusion.system_ids.SYS_CLOAKING] = "FAST_CLOAK",
  [fusion.system_ids.SYS_BATTERY] = "FAST_BATTERY",
  [fusion.system_ids.SYS_MIND] = "FAST_MIND",
  [fusion.system_ids.SYS_HACKING] = "FAST_HACK",
  [fusion.system_ids.SYS_TEMPORAL] = "FAST_TEMPORAL"
}

local function cooldownAugCallback(ship, sys)
  local augName = COOLDOWN_AUGS[sys:GetId()]
  local speedup = math.floor(ship:GetAugmentationValue(augName))
  local newlock = math.max(sys.iLockCount - speedup, 0)
  sys:LockSystem(newlock)
end

local function longMindAugCallback(ship, sys)
  local increment = Hyperspace.FPS.SpeedFactor / 16
  local modifier = 2 ^ ship:GetAugmentationValue("LONG_MIND") --Negative values make the duration shorter, longer values make it longer.
  sys.controlTimer.first = sys.controlTimer.first + (1 / modifier - 1) * increment
end

local function longHackAugCallback(ship, sys)
  local increment = Hyperspace.FPS.SpeedFactor / 16
  local modifier = 2 ^ ship:GetAugmentationValue("LONG_HACK") --Negative values make the duration shorter, longer values make it longer.
  sys.effectTimer.first = sys.effectTimer.first + (1 / modifier - 1) * increment
end

local function hackingDamageAugCallback(ship, sys)
  local hackingSystem = Hyperspace.ships(ship.iShipId).hackingSystem --TODO I don't know why this doesn't work if you just pass the hacking system in.
  local damage = ship:GetAugmentationValue("HACKING_DAMAGE")
  if hackingSystem.currentSystem then
    hackingSystem.currentSystem:PartialDamage(damage)
  end
end

local FUSION_AUGS = {
  {name="FAST_TELEPORT", systemId=fusion.system_ids.SYS_TELEPORTER, registered=false, event=Defines.SystemEvents.ON_SHUTDOWN, callback=cooldownAugCallback, priority = -1000},
  {name="FAST_CLOAK", systemId=fusion.system_ids.SYS_CLOAKING, registered=false, event=Defines.SystemEvents.ON_SHUTDOWN, callback=cooldownAugCallback, priority = -1000},
  {name="FAST_BATTERY", systemId=fusion.system_ids.SYS_BATTERY, registered=false, event=Defines.SystemEvents.ON_SHUTDOWN, callback=cooldownAugCallback, priority = -1000},
  {name="FAST_MIND", systemId=fusion.system_ids.SYS_MIND, registered=false, event=Defines.SystemEvents.ON_SHUTDOWN, callback=cooldownAugCallback, priority = -1000},
  {name="FAST_HACK", systemId=fusion.system_ids.SYS_HACKING, registered=false, event=Defines.SystemEvents.ON_SHUTDOWN, callback=cooldownAugCallback, priority = -1000},
  {name="FAST_TEMPORAL", systemId=fusion.system_ids.SYS_TEMPORAL, registered=false, event=Defines.SystemEvents.ON_SHUTDOWN, callback=cooldownAugCallback, priority = -1000},
  {name="LONG_MIND", systemId=fusion.system_ids.SYS_MIND, registered=false, event=Defines.SystemEvents.ON_RUN, callback=longMindAugCallback, priority = 0},
  {name="LONG_HACK", systemId=fusion.system_ids.SYS_HACKING, registered=false, event=Defines.SystemEvents.ON_RUN, callback=longHackAugCallback, priority = 0},
  {name="HACKING_DAMAGE", systemId=fusion.system_ids.SYS_HACKING, registered=false, event=Defines.SystemEvents.ON_RUN, callback=hackingDamageAugCallback, priority = 0}
}

local function checkActiveAugs()
  for i = 0, 1 do
    local shipManager = Hyperspace.ships(i)
    if not (shipManager == nil) then
      for _,augment in ipairs(FUSION_AUGS) do
        if not (augment.registered) then
          if shipManager:HasAugmentation(augment.name) > 0 then
            --print("Registering", augment.name)
            fusion.on_specific_system_event(augment.event, augment.systemId, augment.callback, augment.priority)
            augment.registered = true
          end
        end
      end
    end
  end
end

--on_init doesn't guarantee that the player's ShipManager will exist, so do this instead.
local mFirstCheckFinished = false
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    local commandGui = Hyperspace.Global.GetInstance():GetCApp().gui
    if mFirstCheckFinished or (not (Hyperspace.ships(0)) or Hyperspace.ships(0).iCustomizeMode == 2 or 
    (commandGui.bPaused or commandGui.bAutoPaused or commandGui.event_pause or commandGui.menu_pause)) then return end
    checkActiveAugs()
    mFirstCheckFinished = true
end)

-- script.on_init(function(newGame)
--   checkActiveAugs() --todo wait until ship manager exists.  This is stupid that it doesn't.
-- end)

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function (ShipManager)
  checkActiveAugs()
end)

--[[--currently not working, battery timer not exposed
script.on_system_event(Defines.SystemEvents.ON_RUN,
function(ship, sys)
  if sys:GetId() == 12 then
    local increment = Hyperspace.FPS.SpeedFactor / 16
    local modifier = 2 ^ ship:GetAugmentationValue("LONG_BATTERY") --Negative values make the duration shorter, longer values make it longer.
    sys.timer.first = sys.timer.first + (1 / modifier - 1) * increment
  end
end)
--]]

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP,
function(ShipManager)
  local deionizationBoost = ShipManager:GetAugmentationValue("DEIONIZATION_BOOST")
  for sys in vter(ShipManager.vSystemList) do
    sys.lockTimer.currTime=sys.lockTimer.currTime + Hyperspace.FPS.SpeedFactor /16 * deionizationBoost
  end
end)