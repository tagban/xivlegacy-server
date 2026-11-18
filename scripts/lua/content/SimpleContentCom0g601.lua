require ("global")
require ("modifiers")
require ("ally")

-- Appetite for Destruction, the spiders that hold the clearing west of
-- Camp Nine Ivies. Beating them ends the duty; the content roster running out
-- of live hostiles fires "battleComplete" to the director
-- (QuestDirectorCom0g601). Seed 133 holds the spiders.

MOBS = { 83, 84, 85 };

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
