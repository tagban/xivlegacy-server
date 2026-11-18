--[[

The Waking Sands' three doors (zone 181, private area PrivateAreaMasterPast),
for when no quest has them. Man200, Man206 and Man304 take the doors over
while they need them; at any other time a player inside could not leave the
hall or reach Minfilia's office, and the entrance did not lead back out. The
door overrides under unique/wil0Event01/privatearea/ call this.

]]

WAKING_SANDS_OFFICE		= {-126.2, 1.2, -160, 1.6};		-- inside Minfilia's door
WAKING_SANDS_HALL		= {-142.75, 1, -160, -1.6};		-- outside it
ULDAH_MARKET_OUTSIDE	= {175, -216.52, 190, 30.5, 2.32};	-- the market-ward entrance in Ul'dah

-- door: "exit" (the entrance, back to Ul'dah), "office_in" (hall side of
-- the office door) or "office_out" (office side).
function wakingSandsDoor(player, door)
	player:EndEvent();
	if (door == "exit") then
		local spot = ULDAH_MARKET_OUTSIDE;
		GetWorldManager():DoZoneChange(player, spot[1], nil, 0, 15, spot[2], spot[3], spot[4], spot[5]);
	elseif (door == "office_in") then
		local spot = WAKING_SANDS_OFFICE;
		GetWorldManager():WarpToPosition(player, spot[1], spot[2], spot[3], spot[4]);
	elseif (door == "office_out") then
		local spot = WAKING_SANDS_HALL;
		GetWorldManager():WarpToPosition(player, spot[1], spot[2], spot[3], spot[4]);
	end
end
