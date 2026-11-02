require ("global")
require ("modifiers")
require ("ally")

-- A Weaver and a Mummer (Gcu303), the imperial scouts on the mesa northeast
-- of Nophica's Wells. The content roster running out of live hostiles fires
-- "battleComplete" to the director (QuestDirectorGcu30301). Seed 155 holds
-- them.

MOBS = { 3543, 3544, 3545 };

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
