require ("global")
require ("dungeon_chests")

--[[

GuildleveBonusTreasureBox: the treasure chest model with a talk event.
Dungeon boss chests use it (map-server runtime/dungeon_chest.rs): talking
to one opens it and hands out its loot (dungeon_chests.lua) to the dungeon
copy's players. Errand leves (map-server leve/battle/errand.rs) use it as
the crates to find.

--]]

function init(npc)
	return false, false, 0, 0;
end

function onEventStarted(player, npc, triggerName)
	-- a crate of the player's errand leve (Horn and Hand faction leves)
	if player:IsLeveCrate(npc) then
		player:OpenLeveCrate(npc);
		player:EndEvent();
		return;
	end
	player:OpenDungeonChest(npc, DungeonChestLoot(npc:GetUniqueId()));
	player:EndEvent();
end
