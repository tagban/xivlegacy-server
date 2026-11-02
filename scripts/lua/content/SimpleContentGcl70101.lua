require ("global")
require ("modifiers")

-- The Weakest Link (Gcl701), the kobold encampment in Upper La Noscea: a War
-- Merit duty. The camp's seven beastmen are worth 1,000 War Merit together
-- (MERIT in quests/gc/gc701.lua); they hold their ground until you pull them,
-- and the content roster running out of live hostiles fires "battleComplete"
-- to the director (QuestDirectorGcl70101). Seed 191 holds them.

MOBS = { 3901, 3902, 3903, 3904, 3905, 3906, 3907 };

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
