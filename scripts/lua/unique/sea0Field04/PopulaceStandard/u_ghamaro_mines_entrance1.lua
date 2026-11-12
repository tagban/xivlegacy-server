require ("global")

-- Zone line: walking into this circle takes the player to U'Ghamaro Mines.
function onEventStarted(player, npc)
	player:EndEvent();
	-- A push the client sends while still loading can name the zone it just left.
	if (player:GetZoneID() ~= 135) then
		return;
	end
	-- Gcl304 takes its own holders in at step 5 (its trigger sits at the same mouth).
	if (player:HasQuest(111420) and player:GetQuest(111420):GetSequence() == 5) then
		return;
	end
	GetWorldManager():DoZoneChange(player, 137, nil, 0, 15, 61.00, 44.11, -2801.00, -1.571);
end
