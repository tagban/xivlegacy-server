require ("global")

-- The ride up to the airship landing (elv0u02a) moves the landing's lift car,
-- the background object that the landing's ship port (uldah_mapshipport_1)
-- also runs. Keep the ship port off this player's screen for the ride and let
-- it stream in fresh with the zone change at the end; then the rides back down
-- from the landing play in full (#481, see wellhead_lift_lvl3.lua).
local function rideToLanding(player)
	player:HideActorByUniqueId("uldah_mapshipport_1", 209);
	callClientFunction(player, "elevatorAskUldah002", 2);
	player:ShowActorByUniqueId("uldah_mapshipport_1", 209);
end

function onEventStarted(player, npc)
	floorChoice = callClientFunction(player, "elevatorAskUldah002", 0);

	if (floorChoice == 1) then
		callClientFunction(player, "elevatorAskUldah002", 1);
		GetWorldManager():DoZoneChange(player, 175, nil, 0, 15, -116.78, 198, 115.7, -2.8911);
	elseif (floorChoice == 2) then
		rideToLanding(player);
		GetWorldManager():DoZoneChange(player, 209, nil, 0, 15, -121.60, 269.8, 135.28, -0.268);
	end

	player:EndEvent();
end
