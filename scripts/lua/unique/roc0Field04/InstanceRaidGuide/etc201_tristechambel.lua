require ("global")
require ("dungeon")

--[[

Sir Tristechambel at Teriggan's Stand, whose magicks take you into the
Aurum Vale. Etc201 holders go in through the quest; anyone else gets the
client's raid prompt (the Aurum Vale, raid list entry 6) and the 1.21
entry rules (dungeon.lua OPEN_RAIDS).

]]

function init(npc)
	return false, false, 0, 0, 0x1eb, 0x2;
end

function onEventStarted(player, npc)
	enterOpenRaid(player, "aurum");
end
