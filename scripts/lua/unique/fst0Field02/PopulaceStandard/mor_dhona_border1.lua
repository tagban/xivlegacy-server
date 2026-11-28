require ("global")

-- Region border: the road at the East Shroud's north end goes on into Mor
-- Dhona, a separate region (no seam), so walking into this circle loads
-- Mor Dhona. The player lands at the south road end there, facing north and
-- clear of the circle that leads back, so they don't bounce (#496).
function onEventStarted(player, npc)
	player:EndEvent();
	-- A push the client sends while still loading can name the zone it just left.
	if (player:GetZoneID() ~= 151) then
		return;
	end
	GetWorldManager():DoZoneChange(player, 190, nil, 0, 15, 282.00, 20.10, 860.00, 3.142);
end
