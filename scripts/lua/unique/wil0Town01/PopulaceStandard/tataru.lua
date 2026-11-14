require ("global")
require ("trl0l3")

-- Tataru in the Quicksand (our placement: in 1.23b she is met only in the Waking Sands).
-- After Man200 she takes the player into the Waking Sands to pick the Path companion again
-- (Trl0l3, see trl0l3.lua).
function onEventStarted(player, npc)
	trl0l3Invite(player, npc);
end
