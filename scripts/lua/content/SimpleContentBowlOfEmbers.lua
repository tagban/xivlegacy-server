require ("global")
require ("modifiers")

-- A copy of the Bowl of Embers (zone 240, dungeon.lua) for the Grand
-- Companies' It Kills with Fire (Gc?101): Ifrit, summoned by the Inferno
-- Flambeau. His fall empties the content roster, which fires
-- "battleComplete" to the director (InstanceRaidLesserIfrit). Seed 142 holds
-- him.

IFRIT = 3500;

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
