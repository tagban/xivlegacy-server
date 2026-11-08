require ("global")

-- Zone line: walking into this circle takes the player to Eastern La Noscea.
function onEventStarted(player, npc)
	player:EndEvent();
	-- A push the client sends while still loading can name the zone it just left.
	if (player:GetZoneID() ~= 132) then
		return;
	end
	GetWorldManager():DoZoneChange(player, 130, nil, 0, 15, 1118.00, 29.40, -790.00, 3.142);
end
