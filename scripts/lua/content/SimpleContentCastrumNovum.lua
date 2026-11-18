require ("global")
require ("modifiers")

-- A copy of Castrum Novum's transmission tower (zone 251, dungeon.lua) for
-- the Grand Companies' United We Stand (Gc?106): its defenders, a magitek
-- vanguard and the lunar transmitter, reached through the aetherial gate in
-- Jagged Crest Cave. Once all of them fall the content roster is empty,
-- which fires "battleComplete" to the director (InstanceRaidBeaconBattle).
-- Seed 151 holds them.

DEFENDERS = { 3528, 3529, 3530, 3531, 3532 };

function onCreate(player, contentArea, director)
	director:AddMember(player);
	for _, id in ipairs(DEFENDERS) do
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
