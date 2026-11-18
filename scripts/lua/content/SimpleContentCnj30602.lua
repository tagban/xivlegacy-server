require ("global")
require ("questbattle")
require ("quests/cnj/cnj306")

-- The Call of Nature (Cnj306): three dreadwolves closing in on a small boy
-- in the Amberscale Rock cave, seen through the Echo. When every foe is down
-- the content has no hostiles left, which fires "battleComplete" to
-- QuestDirectorCnj30602 (see questbattle.lua).

BNPCS = { 4041, 4042, 4043 };
FIGHT_LIMIT_SECONDS = 360;

function onCreate(player, contentArea, director)
	questBattle.create(player, contentArea, director, BNPCS);
end

function onZoneIn(player, contentArea, director)
	player:ChangeMusic(37); -- the 1.x duty theme
end

function onUpdate(tick, area)
	questBattle.update(tick, area, FIGHT_LIMIT_SECONDS, loseCnj306Fight);
end

function onAbort(player, contentArea, director)
	questBattle.abort(player);
end

function onDestroy()
end
