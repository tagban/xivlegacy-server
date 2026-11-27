require ("global")

-- The two rides down from the airship landing play the scenes elv0u0a1 and
-- elv0u0a2. Unlike the other lift scenes, they open with the lift car's ARRIVE
-- schedule and wait for it to finish. Whether it finishes depends on the state
-- the car was left in: after a login on the landing, or after coming up by
-- lift, it never does. The screen stays black with "Skip" and the ride never
-- returns (#476).
--
-- The scene ends as soon as the server sends the player a position. So send
-- one where the player already stands, right behind the ride call. The ride
-- then always returns, and the zone change runs as before.
local function rideDown(player, choice)
	player:RunEventFunction("elevatorAskUldah003", choice);
	local x, y, z, rot = player:GetPos();
	GetWorldManager():DoPlayerMoveInZone(player, x, y, z, rot, 0x11);
	return coroutine.yield("_WAIT_EVENT", player);
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
