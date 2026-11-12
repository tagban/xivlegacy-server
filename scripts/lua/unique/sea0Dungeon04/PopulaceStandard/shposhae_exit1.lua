require ("global")

-- Zone line: walking into this circle takes the player to Lower La Noscea.
function onEventStarted(player, npc)
	player:EndEvent();
	-- A push the client sends while still loading can name the zone it just left.
	if (player:GetZoneID() ~= 235) then
		return;
	end
	GetWorldManager():DoZoneChange(player, 128, nil, 0, 15, 285.00, 26.00, 336.00, 0.059);
end
