require ("global")
require ("questbattle")
require ("quests/etc/etc3l1")

-- Winds of Change (Etc3l1): three imperial operatives in the caves west of Camp Bearded Rock.
-- When every foe is down the content has no hostiles left, which fires
-- "battleComplete" to QuestDirectorEtc3l101 (see questbattle.lua).

BNPCS = { 4110, 4111, 4112 };
FIGHT_LIMIT_SECONDS = 360;

function onCreate(player, contentArea, director)
	questBattle.create(player, contentArea, director, BNPCS);
end

function onZoneIn(player, contentArea, director)
	player:ChangeMusic(37); -- the 1.x duty theme
end

function onUpdate(tick, area)
	questBattle.update(tick, area, FIGHT_LIMIT_SECONDS, loseEtc3l1Fight);
end

function onAbort(player, contentArea, director)
	questBattle.abort(player);
end

function onDestroy()
end
