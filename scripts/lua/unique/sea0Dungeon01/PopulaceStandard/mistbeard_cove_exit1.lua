require ("global")

-- Zone line: walking into this circle takes the player to Western La Noscea.
function onEventStarted(player, npc)
	player:EndEvent();
	-- A push the client sends while still loading can name the zone it just left.
	if (player:GetZoneID() ~= 131) then
		return;
	end
	GetWorldManager():DoZoneChange(player, 129, nil, 0, 15, -1758.00, 29.30, -1500.00, -2.976);
end
