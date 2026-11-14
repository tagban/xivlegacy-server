require ("global")

-- Zone line: walking into this circle takes the player to The Tam-Tara Deepcroft.
function onEventStarted(player, npc)
	player:EndEvent();
	-- A push the client sends while still loading can name the zone it just left.
	if (player:GetZoneID() ~= 150) then
		return;
	end
	GetWorldManager():DoZoneChange(player, 158, nil, 0, 15, 255.00, -12.01, -276.00, -2.142);
end
