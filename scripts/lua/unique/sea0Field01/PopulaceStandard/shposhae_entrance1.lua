require ("global")

-- Zone line: walking into this circle takes the player to Shposhae.
function onEventStarted(player, npc)
	player:EndEvent();
	-- A push the client sends while still loading can name the zone it just left.
	if (player:GetZoneID() ~= 128) then
		return;
	end
	GetWorldManager():DoZoneChange(player, 235, nil, 0, 15, 303.00, 14.34, 269.00, 1.571);
end
