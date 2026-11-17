require ("global")
require ("modifiers")

-- Thornmarch (zone 238, dungeon.lua "thornmarch") for Louisoix's A Feast of
-- Fools (Sum6m0): Good King Moggle Mog XII and seven corrupted moogles in
-- the moogle ring. Their fall empties the content roster, which fires
-- "battleComplete" to the director (InstanceRaidDarkMoogle).

COURT = {1925, 1926, 1927, 1928, 1929, 1930, 1931, 1932};	-- the seven moogles, then the king

function onCreate(player, contentArea, director)
	director:AddMember(player);
	for _, id in ipairs(COURT) do
		director:AddMember(GetWorldManager().SpawnBattleNpcById(id, contentArea));
	end
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
