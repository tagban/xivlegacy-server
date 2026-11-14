require ("global")
require ("dungeon_chests")

--[[

GuildleveBonusTreasureBox: the treasure chest model with a talk event.
Dungeon boss chests use it (map-server runtime/dungeon_chest.rs): talking
to one opens it and hands out its loot (dungeon_chests.lua) to the dungeon
copy's players.

--]]

function init(npc)
	return false, false, 0, 0;
end

function onEventStarted(player, npc, triggerName)
	player:OpenDungeonChest(npc, DungeonChestLoot(npc:GetUniqueId()));
	player:EndEvent();
end
