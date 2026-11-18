require ("global")
require ("questbattle")
require ("quests/cnj/cnj300")

-- Good Knight, Sweet Dreams (Cnj300): two wind elementals and an earth
-- elemental in the Amberscale Rock cave. When every foe is down the content
-- has no hostiles left, which fires "battleComplete" to QuestDirectorCnj30001
-- (see questbattle.lua).

BNPCS = { 4046, 4047, 4048 };
FIGHT_LIMIT_SECONDS = 360;

function onCreate(player, contentArea, director)
	questBattle.create(player, contentArea, director, BNPCS);
end

function onZoneIn(player, contentArea, director)
	player:ChangeMusic(37); -- the 1.x duty theme
end

function onUpdate(tick, area)
	questBattle.update(tick, area, FIGHT_LIMIT_SECONDS, loseCnj300Fight);
end

function onAbort(player, contentArea, director)
	questBattle.abort(player);
end

function onDestroy()
end
