local userdata_table = mods.multiverse.userdata_table
local vter = mods.fusion.vter

local function addNewCrew(shipCrew, ship)
	local function validCrewmember(crewmember)
		return not shipCrew["crew"][crewmember] and crewmember.iShipId == ship.iShipId and crewmember:IsCrew()
	end
	
	for crewmember in vter(ship.vCrewList) do
		if validCrewmember(crewmember) then
			shipCrew["crew"][crewmember] = true
		elseif not shipCrew["repairDrones"][crewmember] and crewmember:CanRepair() then
			shipCrew["repairDrones"][crewmember] = true
		end
	end
	
	for crewmember in vter(Hyperspace.ships(1 - ship.iShipId).vCrewList) do
		if validCrewmember(crewmember) then
			shipCrew["crew"][crewmember] = true
		end
	end
end

local ranOnCrewZero = false
script.on_internal_event(Defines.InternalEvents.GENERATOR_CREATE_SHIP_POST, function(_, _2, _3, _4, ship)
	userdata_table(ship, "mods.fusion.eventCallbacks").shipCrew = {["crew"] = {}, ["repairDrones"] = {}}
	local shipCrew = userdata_table(ship, "mods.fusion.eventCallbacks").shipCrew
	
	addNewCrew(shipCrew, ship)
	
	if ship:HasSystem(13) then
		shipCrew["clonebay"] = ship:GetSystem(13)
	end
	
	ranOnCrewZero = false
end)

-- Use script.on_game_event with "FUSION_ONCREWZERO" to use this
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
	if ship.iShipId == 0 or ship.bAutomated or ranOnCrewZero then return end
	
	local shipCrew = userdata_table(ship, "mods.fusion.eventCallbacks").shipCrew
	-- new crew could potentially be added mid-fight
	addNewCrew(shipCrew, ship)
	
	if shipCrew["clonebay"] and shipCrew["clonebay"]:Functioning() then return end
	
	crewCount = 0
	for crew, _ in pairs(shipCrew["crew"]) do
		if not (crew:IsDead() or crew.health.first <= 0 or crew.extend.noSlot) then
			crewCount = crewCount + 1
		end
	end
	
	if shipCrew["clonebay"] then
		for drone, _ in pairs(shipCrew["repairDrones"]) do
			if not (drone:IsDead() or drone.health.first <= 0 or not drone:Functional()) then
				crewCount = crewCount + 1
			end
		end
	end
	
	if crewCount == 0 then
		ranOnCrewZero = true
		Hyperspace.CustomEventsParser.GetInstance():LoadEvent(Hyperspace.App.world, "FUSION_ONCREWZERO", false, -1)
	end
end, 1001)