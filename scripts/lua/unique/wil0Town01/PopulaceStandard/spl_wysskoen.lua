require ("global")
require ("quests/spl/starlight")

-- A Black Rabbit Traders rep for the Starlight Celebration (Spl0i3, Spl0i4),
-- when no quest of the player's answers for them.
function onEventStarted(player, npc)
	starlightRepTalk(player, npc);
end
