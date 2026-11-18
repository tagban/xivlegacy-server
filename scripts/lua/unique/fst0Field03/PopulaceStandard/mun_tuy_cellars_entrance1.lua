require ("global")

-- Zone line: walking into this circle takes the player to The Mun-Tuy Cellars.
function onEventStarted(player, npc)
	player:EndEvent();
	-- A push the client sends while still loading can name the zone it just left.
	if (player:GetZoneID() ~= 152) then
		return;
	end
	GetWorldManager():DoZoneChange(player, 157, nil, 0, 15, -1043.00, -11.79, -2365.00, -0.571);
end
