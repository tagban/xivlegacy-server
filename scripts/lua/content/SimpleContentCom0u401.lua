require ("global")
require ("modifiers")
require ("ally")

-- Arms Race, the Hellhounds holding Ul'dah's eastern trade route near the
-- Golden Bazaar: Garlean sellswords and one of the hounds they're named for.
-- Beating them ends the duty; the content roster running out of live hostiles
-- fires "battleComplete" to the director (QuestDirectorCom0u401). Seed 126
-- holds the Hellhounds.

MOBS = { 70, 71, 72, 73 };

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
