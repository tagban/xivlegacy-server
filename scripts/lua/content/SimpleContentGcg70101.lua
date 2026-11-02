require ("global")
require ("modifiers")

-- You Don't Have the Rite (Gcg701), the Ixali clearing in the North Shroud: a War
-- Merit duty. The camp's seven beastmen are worth 1,000 War Merit together
-- (MERIT in quests/gc/gc701.lua); they hold their ground until you pull them,
-- and the content roster running out of live hostiles fires "battleComplete"
-- to the director (QuestDirectorGcg70101). Seed 191 holds them.

MOBS = { 3908, 3909, 3910, 3911, 3912, 3913, 3914 };

function onCreate(player, contentArea, director)
	director:AddMember(player);
	director:AddMember(director);
	for _, id in ipairs(MOBS) do
		local mob = GetWorldManager().SpawnBattleNpcById(id, contentArea);
		director:AddMember(mob);
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
