require ("global")
require ("modifiers")

-- A copy of the Howling Eye (zone 239, dungeon.lua "howling_hard") for
-- Louisoix's Taming the Tempest (Sum6g0): Garuda grown stronger. Her fall
-- empties the content roster, which fires "battleComplete" to the director
-- (InstanceRaidNormalGaruda).

GARUDA = 1915;

function onCreate(player, contentArea, director)
	director:AddMember(player);
	local garuda = GetWorldManager().SpawnBattleNpcById(GARUDA, contentArea);
	director:AddMember(garuda);
	-- The player can't die in content yet (no death/return flow there).
	player:SetMod(modifiersGlobal.MinimumHpLock, 1);
end

function onZoneIn(player, contentArea, director)
end

function onUpdate(tick, area)
end

function onAbort(player, contentArea, director)
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
end

function onDestroy()
end
