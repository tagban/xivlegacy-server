require ("global")

-- Zone line: walking into this circle takes the player to Central Shroud.
function onEventStarted(player, npc)
	player:EndEvent();
	-- A push the client sends while still loading can name the zone it just left.
	if (player:GetZoneID() ~= 158) then
		return;
	end
	GetWorldManager():DoZoneChange(player, 150, nil, 0, 15, 284.00, 24.70, -271.00, -2.083);
end
