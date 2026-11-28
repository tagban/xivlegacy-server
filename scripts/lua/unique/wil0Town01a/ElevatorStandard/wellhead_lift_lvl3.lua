require ("global")

-- The two rides down from the airship landing play the scenes elv0u0a1 and
-- elv0u0a2. Unlike the other lift scenes, they open with an ARRIVE shot that
-- runs the landing's lift car (the scene's airport100428 background). The
-- landing's ship port map object (uldah_mapshipport_1, a MapObjShipPort bound
-- to layout 431, instance 3525) runs its own background schedule on that car
-- from the moment it streams in. While it holds the car, the ARRIVE shot never
-- finishes: the screen stays black with "Skip" and the ride never returns
-- (#476, #481).
--
-- So take the ship port off this player's screen for the ride, and put it
-- back before the zone change at its end, which streams it in fresh. The rides
-- up to the landing (wellhead_lift_lvl1.lua, wellhead_lift_lvl2.lua) move the
-- same car and do the same: a ship port that was on screen through a ride up
-- leaves the next ride down on black even once it is hidden.
local function rideDown(player, choice)
	player:HideActorByUniqueId("uldah_mapshipport_1");
	callClientFunction(player, "elevatorAskUldah003", choice);
	player:ShowActorByUniqueId("uldah_mapshipport_1");
end

function onEventStarted(player, npc)
	floorChoice = callClientFunction(player, "elevatorAskUldah003", 0);

	if (floorChoice == 1) then
		rideDown(player, 1);
		GetWorldManager():DoZoneChange(player, 175, nil, 0, 15, -116.78, 198, 115.7, -2.8911);
	elseif (floorChoice == 2) then
		rideDown(player, 2);
		GetWorldManager():DoZoneChange(player, 209, nil, 0, 15, -116.78, 222, 115.7, 2.85);
	end

	player:EndEvent();
end
