require ("global")

-- Zone line: walking into this circle takes the player to Cassiopeia Hollow.
function onEventStarted(player, npc)
	player:EndEvent();
	-- A push the client sends while still loading can name the zone it just left.
	if (player:GetZoneID() ~= 130) then
		return;
	end
	GetWorldManager():DoZoneChange(player, 132, nil, 0, 15, 1153.00, 12.35, -722.00, 1.391);
end
