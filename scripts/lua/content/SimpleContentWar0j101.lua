require ("global")
require ("questbattle")
require ("quests/war/war0j1")

-- Pride and Duty (War0j1): three antling workers at the nest north of Curious
-- Gorge's cave. When every foe is down the content has no hostiles left,
-- which fires "battleComplete" to QuestDirectorWar0j101 (see questbattle.lua).

BNPCS = { 3700, 3701, 3702 };
FIGHT_LIMIT_SECONDS = 360;

function onCreate(player, contentArea, director)
	questBattle.create(player, contentArea, director, BNPCS);
end

function onZoneIn(player, contentArea, director)
	player:ChangeMusic(37); -- the 1.x duty theme
end

function onUpdate(tick, area)
	questBattle.update(tick, area, FIGHT_LIMIT_SECONDS, loseWar0j1Fight);
end

function onAbort(player, contentArea, director)
	questBattle.abort(player);
end

function onDestroy()
end
