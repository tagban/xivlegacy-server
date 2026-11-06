require ("global")
require ("questbattle")
require ("quests/etc/etc3l2")

-- Shot Through the Heart (Etc3l2): the beach east of Cassiopeia Hollow.
-- When every foe is down the content has no hostiles left, which fires
-- "battleComplete" to QuestDirectorEtc3l201 (see questbattle.lua).

BNPCS = { 4131, 4132, 4133 };
FIGHT_LIMIT_SECONDS = 360;

function onCreate(player, contentArea, director)
	questBattle.create(player, contentArea, director, BNPCS);
end

function onZoneIn(player, contentArea, director)
	player:ChangeMusic(37); -- the 1.x duty theme
end

function onUpdate(tick, area)
	questBattle.update(tick, area, FIGHT_LIMIT_SECONDS, loseEtc3l2Fight);
end

function onAbort(player, contentArea, director)
	questBattle.abort(player);
end

function onDestroy()
end
