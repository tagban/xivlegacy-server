require ("global")
require ("quests/spl/moonfire")

-- A Moonfire Faire NPC (The Heat Is On, Bombard Backlash), when no quest
-- of the player's answers for them.
function onEventStarted(player, npc)
	moonfireTalk(player, npc);
end
