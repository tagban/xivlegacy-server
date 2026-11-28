require ("global")

-- Region border: the road at Mor Dhona's south edge goes on into the East
-- Shroud, a separate region (no seam), so walking into this circle loads the
-- East Shroud. The player lands in the clearing below the road's north end
-- there, facing south and clear of the circle that leads back (#496).
function onEventStarted(player, npc)
	player:EndEvent();
	-- A push the client sends while still loading can name the zone it just left.
	if (player:GetZoneID() ~= 190) then
		return;
	end
	GetWorldManager():DoZoneChange(player, 151, nil, 0, 15, 2225.00, 20.20, -1842.00, 0.000);
end
