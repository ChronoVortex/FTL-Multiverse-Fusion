local vter = mods.fusion.vter

--CUSTOM FIRE IMPLEMENTATION

--CONSTANTS
local FIRE_GRID_WIDTH = 40 --Width of the fireSpreader grid
local FIRE_GRID_HEIGHT = 40 --Height of the fireSpreader grid
local SMOKE_ANIMATION_DURATION = 1 --Length of vanilla smoke animation, in seconds
local FIRE_ANIMATION_DURATION = 1 --Length of vanilla fire animation, in seconds

local vanillaSheet = Hyperspace.Resources:GetImageId("effects/largeFire.png")
local get_fire_extend
local mSetupRequested = false

--Globally visible constants table
local constants = setmetatable({}, {
  __newindex = function() error("Attempt to modify a read-only table", 2) end,
  __index = {
    FIRE_EXTEND_INITIALIZATION_LOOP_PRIORITY = 20000, -- The priority of the SHIP_LOOP function where Fire_Extend objects are set up.
    FIRE_STAT_INITIALIZATION_PRIORITY = 10000, --The priority of the SHIP_LOOP function where fire stats are cleared. 
    FIRE_STAT_APPLICATION_PRIORITY = -10000,--The priority of the SHIP_LOOP function where fire effects are applied.
  },
  __metatable = "protected metatable",
})


--UTILITY FUNCTIONS
--Iterator over fires in room
local function fires(room, shipManager)
  --TODO: Expose Room::shipObj so shipManager argument is not required
  local shape = room.rect
  local xOffset = shape.x // 35
  local yOffset = shape.y // 35
  local width = shape.w // 35
  local height = shape.h // 35

  local fireIdx = -1
  return function()
    fireIdx = fireIdx + 1
      if fireIdx < width * height then 
        return shipManager:GetFire(xOffset + fireIdx % width, yOffset + fireIdx // width)
      end
  end   
end

--FIRE MECHANICAL IMPLEMENTATION

--Reimplementation of Spreader_Fire::CheckSquareSpread
local function check_square_spread(shipManager, to, from, timeDilation)
  if from.x < 0 or from.y < 0 or from.x > 40 or from.y > 40 or shipManager:GetFire(from.x, from.y).fDamage <= 0 then 
    return 0
  end
    
  local connected = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId):ConnectedGridSquaresPoint(from, to)
  if connected == 0 then return 0 end
  local doorLevel = 0
  if connected == 2 then
    doorLevel = 1
  elseif connected >= 3 and connected < 6 then 
    doorLevel = 3
  end
    
  --Partial reimplementation of UpdateStartTimer
  local toFire = shipManager:GetFire(to.x, to.y)
  if toFire.fDamage <= 0 then
    local multiplier
    if doorLevel == 1 then
      multiplier = 0.05714286
    elseif doorLevel == 2 then
      multiplier = 0.08
    elseif doorLevel == 3 then
      multiplier = 0.01
    else
      multiplier = 0.1
    end
    local fromFire = shipManager:GetFire(from.x, from.y)
    local spreadSpeedMultiplier = get_fire_extend(fromFire).spreadSpeedMultiplier

    toFire.fStartTimer = toFire.fStartTimer - multiplier * Hyperspace.FPS.SpeedFactor * timeDilation * (spreadSpeedMultiplier - 1)
  end
  return 1
end

local function accelerate_animation(animation, speed, base_time)
  local progress = animation.tracker:Progress(-1)
  if speed == 0 then
    animation.tracker.time = 1000000
  else
    animation.tracker.time = base_time / speed
  end
  animation:SetProgress(progress)
end

local function customFireLoop(shipManager)
  if shipManager == nil then return end
  for room in vter(shipManager.ship.vRoomList) do
    local timeDilation = Hyperspace.TemporalSystemParser.GetDilationStrength(room.extend.timeDilation)
    local fireCount = shipManager:GetFireCount(room.iRoomId)
    --System damage
    local sys = shipManager:GetSystemInRoom(room.iRoomId)
    if sys ~= nil and fireCount ~= 0 then
      local nativeDamage = timeDilation * 0.5 * fireCount
      local desiredDamage = 0
      for fire in fires(room, shipManager) do
        if fire.fDamage > 0 then
          desiredDamage = desiredDamage + (0.5 * timeDilation * get_fire_extend(fire).systemDamageMultiplier)
        end
      end
      sys:DamageOverTime(desiredDamage - nativeDamage)
    end
    --Oxygen drain
    local oxygenSystem = shipManager.oxygenSystem
    if oxygenSystem ~= nil and fireCount ~= 0 then
      local nativeDrain = -0.06 * Hyperspace.FPS.SpeedFactor * fireCount
      local desiredDrain = 0
      for fire in fires(room, shipManager) do
        if fire.fDamage > 0 then
          desiredDrain = desiredDrain + (-0.06 * get_fire_extend(fire).oxygenDrainMultiplier)
        end
      end
      --Temporal system applies effect within modifyRoomOxygen so it is not included in calculation
      oxygenSystem:ModifyRoomOxygen(room.iRoomId, desiredDrain - nativeDrain)
    end

    --Fire death and spread
    local shape = room.rect
    local startX = shape.x // 35
    local startY = shape.y // 35
    local endX = startX + (shape.w // 35) - 1
    local endY = startY + (shape.h // 35) - 1
    for x = startX, endX do
      for y = startY, endY do
        local thisFire = Hyperspace.Point(x, y)
        local top = Hyperspace.Point(x, y - 1)
        local bottom = Hyperspace.Point(x, y + 1)
        local left = Hyperspace.Point(x - 1, y)
        local right = Hyperspace.Point(x + 1, y)

        local connectedFires =  
        check_square_spread(shipManager, thisFire, top, timeDilation) +
        check_square_spread(shipManager, thisFire, bottom, timeDilation) +
        check_square_spread(shipManager, thisFire, left, timeDilation) +
        check_square_spread(shipManager, thisFire, right, timeDilation)
        
        --Partial reimplementation of UpdateDeathTimer
        local fire = shipManager:GetFire(x, y)
        if fire.fDeathTimer > 0 then
          local deathSpeedMultiplier = get_fire_extend(fire).deathSpeedMultiplier
          fire.fDeathTimer = fire.fDeathTimer - (connectedFires * -3 + 15) * 0.01 * Hyperspace.FPS.SpeedFactor * timeDilation * (deathSpeedMultiplier - 1);
          fire.fDeathTimer = math.max(0, fire.fDeathTimer)
        end
        --Animations
        local animationSpeedMultiplier = get_fire_extend(fire).animationSpeedMultiplier
        accelerate_animation(fire.fireAnimation, animationSpeedMultiplier, FIRE_ANIMATION_DURATION)
        local replacementSheet = get_fire_extend(fire).replacementSheet
        if replacementSheet ~= nil then
          fire.fireAnimation.animationStrip = replacementSheet
          fire.fireAnimation.primitive = nil
          fire.fireAnimation.mirroredPrimitive = nil
        elseif fire.fireAnimation.animationStrip ~= vanillaSheet then
          fire.fireAnimation.animationStrip = vanillaSheet
          fire.fireAnimation.primitive = nil
          fire.fireAnimation.mirroredPrimitive = nil
        end
        accelerate_animation(fire.smokeAnimation, animationSpeedMultiplier, SMOKE_ANIMATION_DURATION) 
      end
    end
  end
end

--EXTENDED FIRE IMPLEMENTATION
local Fire_Extend = {}
function Fire_Extend:New()
  local fire_extend = {

    systemDamageMultiplier = 1,
    spreadSpeedMultiplier = 1,
    deathSpeedMultiplier = 1,
    oxygenDrainMultiplier = 1,
    animationSpeedMultiplier = 1,
    replacementSheet = nil,
  }
  return setmetatable(fire_extend, {__index = Fire_Extend})
end

function Fire_Extend:Reset()
  self.systemDamageMultiplier = 1
  self.spreadSpeedMultiplier = 1
  self.deathSpeedMultiplier = 1
  self.oxygenDrainMultiplier = 1
  self.animationSpeedMultiplier = 1
  self.replacementSheet = nil
end

local fireExtends = {[0] = {}, [1] = {}}
local function get_fire_idx(fire)
  local x = fire.pLoc.x // 35
  local y = fire.pLoc.y // 35
  return math.floor(y * FIRE_GRID_WIDTH + x)
end


--Return a table that corresponds to a fire
get_fire_extend = function(fire)
  if not mSetupRequested then
    mSetupRequested = true
    customFireLoop(Hyperspace.ships(fire.shipObj.iShipId))
  end
  local argType = swig_type(fire)
  local expectedType = "Fire *"
  if argType ~= expectedType then
    local errorMessage = string.format("Error in get_fire_extend: Expected arg of type: %s, recieved arg of type: %s", expectedType, argType)
    error(errorMessage, 2) 
  end

  local extend = fireExtends[fire.shipObj.iShipId][get_fire_idx(fire)]
  if extend == nil then
    error("No extended object for fire!", 2)
  end
  return extend
end

--Table construction/cleanup

--Rooms are not initialized in ShipManager construction, so the actual setup has to take place in SHIP_LOOP
script.on_internal_event(Defines.InternalEvents.CONSTRUCT_SHIP_MANAGER, 
function(shipManager)
  --Free old table and mark for setup
  fireExtends[shipManager.iShipId] = nil 
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, 
function(shipManager)
  if fireExtends[shipManager.iShipId] == nil then
  --Create new table
    local extends = {}
    for room in vter(shipManager.ship.vRoomList) do
      for fire in fires(room, shipManager) do
        local idx = get_fire_idx(fire)
          extends[idx] = Fire_Extend:New()
      end
    end
    fireExtends[shipManager.iShipId] = extends
  end
end, constants.FIRE_EXTEND_INITIALIZATION_LOOP_PRIORITY)



--Reset fire values on tick
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, 
function(shipManager)
  if not mSetupRequested then return end
  for room in vter(shipManager.ship.vRoomList) do
    for fire in fires(room, shipManager) do
      get_fire_extend(fire):Reset()
    end
  end
end, constants.FIRE_STAT_INITIALIZATION_PRIORITY)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, 
function(shipManager)
  if not mSetupRequested then return end
  return customFireLoop(shipManager)
end, constants.FIRE_STAT_APPLICATION_PRIORITY)
--TODO: Implement fires with crew damage and crew repair multipliers once lua statboosts are active


--PUBLIC API
mods.fusion.custom_fires = {}
mods.fusion.custom_fires.get_fire_extend = get_fire_extend --Get the extend attributes of an individual fire. Only works for valid fires within a room.
mods.fusion.custom_fires.fires = fires --Iterate over all fires in a room.
mods.fusion.custom_fires.constants = constants --Globally visible constants table

--LEGACY BEHAVIORS

--list of crew/drones that affect fire speed in a room
mods.fusion.burnSpeedCrew ={
  --exampleCrew = {0.5, 2} --makes fires in your ship do system damage slower and those on enemy do system damage faster
}
local burnSpeedCrew = mods.fusion.burnSpeedCrew
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP,
function(shipManager)
  local roomFireMult = {}

  for room in vter(shipManager.ship.vRoomList) do
    roomFireMult[room.iRoomId] = 1
  end

  for crew in vter(shipManager.vCrewList) do
    local fireMod = burnSpeedCrew[crew:GetSpecies()]
    if fireMod then
      local room = crew.iRoomId
      if crew:GetIntruder() then
        roomFireMult[room] = roomFireMult[room] * fireMod[2]
      else
        roomFireMult[room] = roomFireMult[room] * fireMod[1]
      end
    end
  end
  
  local augMult = 1 - shipManager:GetAugmentationValue("FIRE_IMMUNITY")

  for room in vter(shipManager.ship.vRoomList) do
    local crewMult = roomFireMult[room.iRoomId]
    for fire in fires(room, shipManager) do
      get_fire_extend(fire).systemDamageMultiplier = get_fire_extend(fire).systemDamageMultiplier * crewMult * augMult
    end
  end
end, constants.FIRE_STAT_APPLICATION_PRIORITY + 1)