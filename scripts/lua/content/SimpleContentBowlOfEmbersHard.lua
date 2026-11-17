require ("global")
require ("modifiers")

-- A copy of the Bowl of Embers (zone 240, dungeon.lua "embers_hard") for
-- Louisoix's Ifrit Bleeds, We Can Kill It (Sum6a0): Ifrit grown stronger.
-- His fall empties the content roster, which fires "battleComplete" to the
-- director (InstanceRaidNormalIfrit).

IFRIT = 1906;

function onCreate(player, contentArea, director)
	director:AddMember(player);
	local ifrit = GetWorldManager().SpawnBattleNpcById(IFRIT, contentArea);
	director:AddMember(ifrit);
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
