require ("global")
require ("dungeon")

--[[

The Immortal Flames sentry at Cutter's Pass, posted by the Flame General to
keep watch over Cutter's Cry. Anyone who meets the 1.21 entry rules
(dungeon.lua OPEN_RAIDS) gets the client's raid prompt (Cutter's Cry, raid
list entry 7) and goes in with their party. Retail's sentry stood at the
cave mouth; no 1.0 position survives, so he stands by the camp's aetherial
gate, where the dungeon's exit sets you down.

]]

function init(npc)
	return false, false, 0, 0, 0x1eb, 0x2;
end

function onEventStarted(player, npc)
	enterOpenRaid(player, "cutters");
end
