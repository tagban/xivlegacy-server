require ("global")
require ("questbattle")
require ("quests/etc/etc1u7")

-- Clasping to Hope (Etc1u7): the Amalj'aa warband near Halatali.
-- When every foe is down the content has no hostiles left, which fires
-- "battleComplete" to QuestDirectorEtc1u701 (see questbattle.lua).

BNPCS = { 4134, 4135, 4136 };
FIGHT_LIMIT_SECONDS = 360;

function onCreate(player, contentArea, director)
	questBattle.create(player, contentArea, director, BNPCS);
end

function onZoneIn(player, contentArea, director)
	player:ChangeMusic(37); -- the 1.x duty theme
end

function onUpdate(tick, area)
	questBattle.update(tick, area, FIGHT_LIMIT_SECONDS, loseEtc1u7Fight);
end

function onAbort(player, contentArea, director)
	questBattle.abort(player);
end

function onDestroy()
end
