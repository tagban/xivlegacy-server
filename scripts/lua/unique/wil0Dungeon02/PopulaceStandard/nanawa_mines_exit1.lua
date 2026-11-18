require ("global")

-- Zone line: walking into this circle takes the player to Central Thanalan.
function onEventStarted(player, npc)
	player:EndEvent();
	-- A push the client sends while still loading can name the zone it just left.
	if (player:GetZoneID() ~= 176) then
		return;
	end
	GetWorldManager():DoZoneChange(player, 170, nil, 0, 15, 103.20, 182.09, -1066.40, 0.349);
end
