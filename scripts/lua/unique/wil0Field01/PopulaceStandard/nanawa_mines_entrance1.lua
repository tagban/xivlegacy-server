require ("global")

-- Zone line: walking into this circle takes the player to Nanawa Mines.
function onEventStarted(player, npc)
	player:EndEvent();
	-- A push the client sends while still loading can name the zone it just left.
	if (player:GetZoneID() ~= 170) then
		return;
	end
	GetWorldManager():DoZoneChange(player, 176, nil, 0, 15, 109.00, 174.54, -1125.00, 2.622);
end
