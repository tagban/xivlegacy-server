require ("global")

-- Zone line: walking into this circle takes the player to Western Thanalan.
function onEventStarted(player, npc)
	player:EndEvent();
	-- A push the client sends while still loading can name the zone it just left.
	if (player:GetZoneID() ~= 178) then
		return;
	end
	GetWorldManager():DoZoneChange(player, 172, nil, 0, 15, -726.20, 118.00, -88.80, -1.184);
end
