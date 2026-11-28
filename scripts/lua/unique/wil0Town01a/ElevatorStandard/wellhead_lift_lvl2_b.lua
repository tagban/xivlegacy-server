require ("global")

-- The second lift actor at the Hustings Strip stop (class 1290023, spawn
-- row 266), next to wellhead_lift_lvl2 (class 1090461, row 260) on the
-- same spot. 1090461 is the Wellhead lift's own class (1090460-1090462 are
-- its three floors) and carries the "!" lift button (push command 10013).
-- 1290023 is the plain ElevatorStandard class that Limsa's Crow's lift uses
-- (1290007-1290009), with no push command: it offers no button, and its
-- silent push circles send nothing to the server, so players never start
-- an event on it. It had the same unique id as 1090461, which made lookups
-- by unique id in zone 209 pick either actor (#482). It keeps its own id now,
-- and should anything ever start an event on it, it runs the same floor
-- menu as the Hustings Strip lift.
function onEventStarted(player, npc)
	floorChoice = callClientFunction(player, "elevatorAskUldah002", 0);

	if (floorChoice == 1) then
		callClientFunction(player, "elevatorAskUldah002", 1);
		GetWorldManager():DoZoneChange(player, 175, nil, 0, 15, -116.78, 198, 115.7, -2.8911);
	elseif (floorChoice == 2) then
		callClientFunction(player, "elevatorAskUldah002", 2);
		GetWorldManager():DoZoneChange(player, 209, nil, 0, 15, -121.60, 269.8, 135.28, -0.268);
	end

	player:EndEvent();
end
