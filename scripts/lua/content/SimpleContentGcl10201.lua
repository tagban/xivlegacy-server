require ("global")
require ("modifiers")
require ("ally")

-- Alive (Gcl102), the imperial operatives on the northern pass into Oakwood.
-- Beating them ends the duty; the content roster running out of live
-- hostiles fires "battleComplete" to the director (QuestDirectorGcl10201).
-- Seed 143 holds them.

MOBS = { 3507, 3508, 3509, 3510 };

function onCreate(player, contentArea, director)
	director:AddMember(player);
	director:AddMember(director);
	for _, id in ipairs(MOBS) do
		local mob = GetWorldManager().SpawnBattleNpcById(id, contentArea);
		mob:ChangeState(2);
		director:AddMember(mob);
		allyGlobal.EngageTarget(mob, player);
	end
	-- The player can't die in content yet (no death/return flow there).
	player:SetMod(modifiersGlobal.MinimumHpLock, 1);
end

function onZoneIn(player, contentArea, director)
	player:ChangeMusic(37); -- the 1.x duty theme
end

function onUpdate(tick, area)
end

function onAbort(player, contentArea, director)
end

function onDestroy()
end
