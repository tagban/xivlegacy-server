require ("global")
require ("questbattle")
require ("quests/etc/etc3g2")

-- Disorganized Crime (Etc3g2): the Redbelly Wasps at Lifemend Stump.
-- When every foe is down the content has no hostiles left, which fires
-- "battleComplete" to QuestDirectorEtc3g201 (see questbattle.lua).

BNPCS = { 4128, 4129, 4130 };
FIGHT_LIMIT_SECONDS = 360;

function onCreate(player, contentArea, director)
	questBattle.create(player, contentArea, director, BNPCS);
end

function onZoneIn(player, contentArea, director)
	player:ChangeMusic(37); -- the 1.x duty theme
end

function onUpdate(tick, area)
	questBattle.update(tick, area, FIGHT_LIMIT_SECONDS, loseEtc3g2Fight);
end

function onAbort(player, contentArea, director)
	questBattle.abort(player);
end

function onDestroy()
end
