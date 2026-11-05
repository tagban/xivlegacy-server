require ("global")
require ("questbattle")
require ("quests/etc/etc3g1")

-- Scrubbing the Soul (Etc3g1): three imperial soldiers by the scarred tree south of Camp Bentbranch.
-- When every foe is down the content has no hostiles left, which fires
-- "battleComplete" to QuestDirectorEtc3g101 (see questbattle.lua).

BNPCS = { 4113, 4114, 4115 };
FIGHT_LIMIT_SECONDS = 360;

function onCreate(player, contentArea, director)
	questBattle.create(player, contentArea, director, BNPCS);
end

function onZoneIn(player, contentArea, director)
	player:ChangeMusic(37); -- the 1.x duty theme
end

function onUpdate(tick, area)
	questBattle.update(tick, area, FIGHT_LIMIT_SECONDS, loseEtc3g1Fight);
end

function onAbort(player, contentArea, director)
	questBattle.abort(player);
end

function onDestroy()
end
