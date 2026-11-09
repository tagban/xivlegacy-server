require ("global")

-- Zone line: walking into this circle takes the player to North Shroud.
function onEventStarted(player, npc)
	player:EndEvent();
	-- A push the client sends while still loading can name the zone it just left.
	if (player:GetZoneID() ~= 157) then
		return;
	end
	GetWorldManager():DoZoneChange(player, 152, nil, 0, 15, -1029.20, 3.02, -2424.20, -2.883);
end
