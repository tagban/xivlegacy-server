require ("global")
require ("quests/spl/hatchingtide")

-- A Hatching-tide NPC (the Dreamer's quests), when no quest of the
-- player's answers for them.
function onEventStarted(player, npc)
	hatchingtideTalk(player, npc);
end
