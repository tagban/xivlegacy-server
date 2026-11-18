require ("global")

-- Zone line: walking into this circle takes the player to The Mun-Tuy Cellars.
function onEventStarted(player, npc)
	player:EndEvent();
	-- A push the client sends while still loading can name the zone it just left.
	if (player:GetZoneID() ~= 152) then
		return;
	end
	GetWorldManager():DoZoneChange(player, 157, nil, 0, 15, -691.00, 3.74, -1987.00, 2.678);
end
