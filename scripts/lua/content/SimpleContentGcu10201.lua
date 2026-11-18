require ("global")
require ("modifiers")
require ("ally")

-- Like Father, Like Son (Gcu102), the Garleans at the cave north-west of Camp
-- Black Brush. Beating them ends the duty; the content roster running out of
-- live hostiles fires "battleComplete" to the director
-- (QuestDirectorGcu10201). Seed 145 holds them.

MOBS = { 3515, 3516, 3517, 3518 };

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
