require ("global")

-- The ride up to the airship landing (elv0u01a) moves the landing's lift car,
-- the background object that the landing's ship port (uldah_mapshipport_1 in
-- zone 209) also runs. Keep the ship port off this player's screen for the
-- ride and let it stream in fresh with the zone change at the end; then the
-- rides back down from the landing play in full (#481, see
-- wellhead_lift_lvl3.lua).
local function rideToLanding(player)
	player:HideActorByUniqueId("uldah_mapshipport_1", 209);
	callClientFunction(player, "elevatorAskUldah001", 2);
	player:ShowActorByUniqueId("uldah_mapshipport_1", 209);
end

function onEventStarted(player, npc)
	floorChoice = callClientFunction(player, "elevatorAskUldah001", 0);

	if (floorChoice == 1) then
		callClientFunction(player, "elevatorAskUldah001", 1);
		GetWorldManager():DoZoneChange(player, 209, nil, 0, 15, -116.78, 222, 115.7, 2.85);
	elseif (floorChoice == 2) then
		rideToLanding(player);
		GetWorldManager():DoZoneChange(player, 209, nil, 0, 15, -121.60, 269.8, 135.28, -0.268);
	end

	player:EndEvent();
end
