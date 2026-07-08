local vter = mods.fusion.vter
local real_projectile = mods.fusion.real_projectile
local randomInt = mods.fusion.randomInt
mods.fusion.system_ids = {}
local fusion = mods.fusion

mods.fusion.system_ids.SYS_SHIELDS = 0
mods.fusion.system_ids.SYS_ENGINES = 1
mods.fusion.system_ids.SYS_OXYGEN = 2
mods.fusion.system_ids.SYS_WEAPONS = 3
mods.fusion.system_ids.SYS_DRONES = 4
mods.fusion.system_ids.SYS_MEDBAY = 5
mods.fusion.system_ids.SYS_PILOT = 6
mods.fusion.system_ids.SYS_SENSORS = 7
mods.fusion.system_ids.SYS_DOORS = 8
mods.fusion.system_ids.SYS_TELEPORTER = 9
mods.fusion.system_ids.SYS_CLOAKING = 10
mods.fusion.system_ids.SYS_ARTILLERY = 11
mods.fusion.system_ids.SYS_BATTERY = 12
mods.fusion.system_ids.SYS_CLONEBAY = 13
mods.fusion.system_ids.SYS_MIND = 14
mods.fusion.system_ids.SYS_HACKING = 15
mods.fusion.system_ids.SYS_TEMPORAL = 20

--todo these are not all the fields
---@class (Exact) FireEvent
---@field name string
---@field systemId number 
---@field add function
---@field setupFunction function
---@field usageRequested boolean

---@class (Exact) SystemEvent
---@field name string
---@field add function

local FireEventIds = {WEAPON_FIRE="Defines.FireEvents.WEAPON_FIRE",
                      ARTILLERY_FIRE="Defines.FireEvents.ARTILLERY_FIRE"
}

local SystemEventIds = {ON_ACTIVATE="Defines.SystemEvents.ON_ACTIVATE",
                      ON_SHUTDOWN="Defines.SystemEvents.ON_SHUTDOWN",
                      ON_RUN="Defines.SystemEvents.ON_RUN"
}

local mTrackedSystemIds = {}


local function createWeaponsLoop()
  script.on_internal_event(Defines.InternalEvents.ON_TICK,
    function()
      for i = 0, 1 do
        local weapons = nil
        local ship = Hyperspace.ships(i)
        pcall(function() weapons = ship.weaponSystem.weapons end)
        if weapons and ship.weaponSystem:Powered() then 
          for weapon in vter(weapons) do
            while true do
              local projectile = weapon:GetProjectile()
              if projectile then
                Hyperspace.Global.GetInstance():GetCApp().world.space.projectiles:push_back(projectile)
                Defines.FireEvents.WEAPON_FIRE(ship, weapon, projectile)
              else
                break
              end
            end
          end
        end
      end
    end, 1000)
end

local function createArtilleryLoop()
  script.on_internal_event(Defines.InternalEvents.ON_TICK,
    function()
      for i = 0, 1 do
        local artilleries = nil
        local ship = Hyperspace.ships(i)
        pcall(function() artilleries = ship.artillerySystems end)
        if artilleries then 
          for artillery in vter(artilleries) do
            while true do
              local weapon = artillery.projectileFactory
              local projectile = weapon:GetProjectile()
              if projectile then
                Hyperspace.Global.GetInstance():GetCApp().world.space.projectiles:push_back(projectile)
                Defines.FireEvents.ARTILLERY_FIRE(ship, artillery, projectile)
              else
                break
              end
            end
          end
        end
      end
    end, 1000)
end


local callback_runner = {
    identifier = "",

  __call = function(self, ...)
    for key,functable in ipairs(self) do
      for _,func in ipairs(functable) do
        local success, res = pcall(func, ...)
        if not success then
          log(string.format(
          "Failed to call function in callback '%s' due to error:\n %s",
          self.identifier,
          res))
        elseif res then return end
      end
    end
  end,

  add = function(self, func, systemId, priority)
    local priority = priority or 0
    if type(priority) ~= 'number' or math.floor(priority) ~= priority then
      error("Priority argument must be an integer!", 3)
    end
    local priority = priority or 0
    local ptab = nil
    for _,v in ipairs(self) do
      if getmetatable(v).priority == priority then
        ptab = v break
      end
    end
    if not ptab then
      ptab = setmetatable({}, {priority = priority})
      table.insert(self, ptab)
    end
    if type(func) ~= 'function' then
      error("Second argument must be a function!", 3)
    end
    local function wrapperFunc(ShipManager, System) --Wrap function to only call it if it's triggered by the associated system.
       if systemId == System:GetId() then
          return func(ShipManager, System)
       end
    end
    table.insert(ptab, wrapperFunc)
    table.sort(self,
    function(lesser,greater)
      return getmetatable(lesser).priority > getmetatable(greater).priority --larger numbers come first
    end)
  end,

  new = function(self, o)
    o = o or {}
    self.__index = self
    setmetatable(o, self)
    return o
  end,
}

---These events only work with systems with timers and cooldowns.
---ON_ACTIVATE Called the first frame a system is activated
---ON_RUN     Called every non-first frame a system is active
---ON_SHUTDOWN Called when an active system becomes inactive.
Defines.SystemEvents = {
  ON_ACTIVATE = callback_runner:new({identifier = SystemEventIds[ON_ACTIVATE]}),
  ON_SHUTDOWN = callback_runner:new({identifier = SystemEventIds[ON_SHUTDOWN]}),
  ON_RUN = callback_runner:new({identifier = SystemEventIds[ON_RUN]}),
}

---WEAPON_FIRE  Called whenever a weapon fires
---ARTILLERY_FIRE Called whenever an artillery fires
Defines.FireEvents = {
  WEAPON_FIRE = callback_runner:new({identifier = FireEventIds[WEAPON_FIRE]}),
  ARTILLERY_FIRE = callback_runner:new({identifier = FireEventIds[ARTILLERY_FIRE]}),
}
Defines.FireEvents.WEAPON_FIRE.setupFunction = createWeaponsLoop
Defines.FireEvents.ARTILLERY_FIRE.setupFunction = createArtilleryLoop
Defines.FireEvents.WEAPON_FIRE.systemId = mods.fusion.system_ids.SYS_ARTILLERY
Defines.FireEvents.ARTILLERY_FIRE.systemId = mods.fusion.system_ids.SYS_WEAPONS

local system_callbacks = {
  name="",
  just_on = {[0] = false, [1] = false},
  procedure = function(self)
    for i = 0, 1 do
      local sys = nil
      pcall(function()
        if type(self.name) == 'string' then
          sys = Hyperspace.ships(i)[self.name]
        else
          sys = Hyperspace.ships(i):GetSystem(self.name)
        end
      end)
      if sys then
        if sys.iLockCount == -1 then --if the system is locked
          if not self.just_on[i] then-- if the system is locked and was not activated last frame, meaning it was just turned on
            Defines.SystemEvents.ON_ACTIVATE(Hyperspace.ships(i), sys)
            --print("on activate triggered for", sys)
          end
          self.just_on[i] = true
          if not Hyperspace.Global.GetInstance():GetCApp().world.space.gamePaused then
            --print("on run triggered for", sys)
            Defines.SystemEvents.ON_RUN(Hyperspace.ships(i), sys)
          end
        elseif self.just_on[i] then --if the system was locked (meaning activated) last frame and is no longer locked
          self.just_on[i] = false
          Defines.SystemEvents.ON_SHUTDOWN(Hyperspace.ships(i), sys)
            --print("on shutdown triggered for", sys)
        end
      end
    end
  end,

  new = function(self,name)
    --all system_callbacks objects will share the same 'shutdown', 'activate', and 'run' tables, similar to Hyperspace's callbacks with arguments
    self.__index = self
    local table = setmetatable({}, self)
    table.just_on = {[0] = false, [1] = false}
    table.name = name
    script.on_internal_event(Defines.InternalEvents.ON_TICK, function() table:procedure() end, 1000)
    return table
  end,
}

---comment
---@deprecated This method causes high resource usage, use script.on_specific_system_event instead.
---@param SystemEvent SystemEvent
---@param SystemId number
---@param func function that takes arguments ShipManager, System
---@param priority number higher priority functions are applied first
local function on_system_event(SystemEvent, SystemId, func, priority)
  local validEvent = false
  for _, v in pairs(Defines.SystemEvents) do
    if v == SystemEvent then validEvent = true break end
  end
  if not validEvent then
    log("\n\nValid SystemEvents:\nON_ACTIVATE\nON_SHUTDOWN\nON_RUN")
    error("First argument of function 'on_system_event' must be a valid SystemEvent! Check the FTL_HS.log file for more information.", 2)
  end
  SystemEvent:add(func, SystemId, priority)
end

--#region ----------API-------------

---Creates a listener for a specific system event on a specific system.
---There is no additional overhead cost for registering multiple events on the same system,
---but it does cost more to register multiple systems.
---
---This only supports systems that have some kind of activated ability, as activations are what these events track.
---@param SystemEvent SystemEvent
---@param SystemId number
---@param func function that takes arguments ShipManager, System
---@param priority number higher priority functions are applied first
function fusion.on_specific_system_event(SystemEvent, SystemId, func, priority)
  if not mTrackedSystemIds[SystemId] then
    system_callbacks:new(SystemId)
    mTrackedSystemIds[SystemId] = true
  end
  on_system_event(SystemEvent, SystemId, func, priority)
end

---
---@param FireEvent FireEvent
---@param func function that takes arguments ShipManager, Weapon, Projectile
---@param priority number higher priority functions are applied first
function script.on_fire_event(FireEvent, func, priority)
  local validEvent = false
  for _, v in pairs(Defines.FireEvents) do
    if v == FireEvent then validEvent = true break end
  end
  if not validEvent then
    log("\n\nValid FireEvents:\nWEAPON_FIRE\nARTILLERY_FIRE")
    error("First argument of function 'script.on_fire_event' must be a valid FireEvent! Check the FTL_HS.log file for more information.", 2)
  end

  print(FireEvent.name, FireEvent.add, FireEvent.setupFunction, FireEvent.usageRequested)
  if not FireEvent.usageRequested then
    FireEvent.setupFunction()
  end
  FireEvent:add(func, FireEvent.systemId, priority)
end
--#endregion -------------------------------------------