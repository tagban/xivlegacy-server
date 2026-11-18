require ("global")

-- Zone line: walking into this circle takes the player to Copperbell Mines.
function onEventStarted(player, npc)
	player:EndEvent();
	-- A push the client sends while still loading can name the zone it just left.
	if (player:GetZoneID() ~= 172) then
		return;
	end
	GetWorldManager():DoZoneChange(player, 178, nil, 0, 15, -667.00, 111.74, -83.00, 1.052);
end
