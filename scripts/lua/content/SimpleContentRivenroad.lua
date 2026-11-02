require ("global")
require ("modifiers")

-- A copy of Rivenroad (zone 257, dungeon.lua) for the Grand Companies' To
-- Kill a Raven (Gc?107): Nael van Darnus on the Allagan dais at the heart of
-- the floating isle, reached aboard the Enterprise. His fall empties the
-- content roster, which fires "battleComplete" to the director
-- (InstanceRaidLesserWhiteGeneral). Seed 152 holds him.

NAEL_VAN_DARNUS = 3533;

function onCreate(player, contentArea, director)
	director:AddMember(player);
	local nael = GetWorldManager().SpawnBattleNpcById(NAEL_VAN_DARNUS, contentArea);
	director:AddMember(nael);
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
