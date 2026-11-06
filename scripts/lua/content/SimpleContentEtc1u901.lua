require ("global")
require ("questbattle")
require ("quests/etc/etc1u9")

-- Best Flower Ever (Etc1u9): the rabid dodos in the valley below Sasapano.
-- When every foe is down the content has no hostiles left, which fires
-- "battleComplete" to QuestDirectorEtc1u901 (see questbattle.lua).

BNPCS = { 4056, 4057, 4058 };
FIGHT_LIMIT_SECONDS = 360;

function onCreate(player, contentArea, director)
	questBattle.create(player, contentArea, director, BNPCS);
end

function onZoneIn(player, contentArea, director)
	player:ChangeMusic(37); -- the 1.x duty theme
end

function onUpdate(tick, area)
	questBattle.update(tick, area, FIGHT_LIMIT_SECONDS, loseEtc1u9Fight);
end

function onAbort(player, contentArea, director)
	questBattle.abort(player);
end

function onDestroy()
end
