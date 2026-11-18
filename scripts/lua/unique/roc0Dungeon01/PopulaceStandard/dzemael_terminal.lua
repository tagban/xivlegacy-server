require ("global")
require ("dungeon")

-- The magitek terminal in the Darkhold's farthest chamber
-- (SimpleContentDungeonDzemael.lua spawns it in every copy). The Into the
-- Dark quests (Com5x1) take a talk to it themselves while they are under
-- way; for everyone else (the quest done, or entered with !dungeon) it is
-- the same way out, to Boulder Downs.
function onEventStarted(player, npc)
	player:EndEvent();
	if (player:GetZoneID() ~= DUNGEONS.dzemael.zone) then
		return;
	end
	leaveDungeon(player);
end
