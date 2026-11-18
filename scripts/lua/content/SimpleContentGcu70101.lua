require ("global")
require ("modifiers")

-- Gore a Lizard, Hurry (Gcu701), the Amalj'aa camp by the altar in Eastern Thanalan: a War
-- Merit duty. The camp's seven beastmen are worth 1,000 War Merit together
-- (MERIT in quests/gc/gc701.lua); they hold their ground until you pull them,
-- and the content roster running out of live hostiles fires "battleComplete"
-- to the director (QuestDirectorGcu70101). Seed 191 holds them.

MOBS = { 3915, 3916, 3917, 3918, 3919, 3920, 3921 };

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
