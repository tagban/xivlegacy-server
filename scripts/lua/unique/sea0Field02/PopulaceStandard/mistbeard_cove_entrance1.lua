require ("global")

-- Zone line: walking into this circle takes the player to Mistbeard Cove.
function onEventStarted(player, npc)
	player:EndEvent();
	-- A push the client sends while still loading can name the zone it just left.
	if (player:GetZoneID() ~= 129) then
		return;
	end
	GetWorldManager():DoZoneChange(player, 131, nil, 0, 15, -1810.00, -19.90, -1510.00, 2.799);
end
