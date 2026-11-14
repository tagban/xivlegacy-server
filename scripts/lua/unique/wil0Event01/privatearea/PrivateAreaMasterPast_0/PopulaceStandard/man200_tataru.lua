require ("global")
require ("trl0l3")

-- Tataru in the Waking Sands when no quest has her: the Path companion re-pick (Trl0l3).
function onEventStarted(player, npc)
	trl0l3Reselect(player, npc);
end
