require ("global")
require ("questbattle")
require ("quests/etc/etc2u5")

-- No Other Dodo Will Do (Etc2u5): three clever dodos north of Camp Drybone.
-- When every foe is down the content has no hostiles left, which fires
-- "battleComplete" to QuestDirectorEtc2u501 (see questbattle.lua).

BNPCS = { 4053, 4054, 4055 };
FIGHT_LIMIT_SECONDS = 360;

function onCreate(player, contentArea, director)
	questBattle.create(player, contentArea, director, BNPCS);
end

function onZoneIn(player, contentArea, director)
	player:ChangeMusic(37); -- the 1.x duty theme
end

function onUpdate(tick, area)
	questBattle.update(tick, area, FIGHT_LIMIT_SECONDS, loseEtc2u5Fight);
end

function onAbort(player, contentArea, director)
	questBattle.abort(player);
end

function onDestroy()
end
