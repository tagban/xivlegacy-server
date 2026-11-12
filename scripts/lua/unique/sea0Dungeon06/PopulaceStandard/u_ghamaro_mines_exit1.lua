require ("global")

-- Zone line: walking into this circle takes the player to Upper La Noscea.
function onEventStarted(player, npc)
	player:EndEvent();
	-- A push the client sends while still loading can name the zone it just left.
	if (player:GetZoneID() ~= 137) then
		return;
	end
	GetWorldManager():DoZoneChange(player, 135, nil, 0, 15, 97.10, 64.40, -2702.80, -0.039);
end
