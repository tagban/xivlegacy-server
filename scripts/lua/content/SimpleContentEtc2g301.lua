require ("global")
require ("questbattle")
require ("quests/etc/etc2g3")

-- Hunting the Hunters (Etc2g3): four Ixali bravos near Quarrymill.
-- When every foe is down the content has no hostiles left, which fires
-- "battleComplete" to QuestDirectorEtc2g301 (see questbattle.lua).

BNPCS = { 4069, 4070, 4071, 4072 };
FIGHT_LIMIT_SECONDS = 360;

function onCreate(player, contentArea, director)
	questBattle.create(player, contentArea, director, BNPCS);
end

function onZoneIn(player, contentArea, director)
	player:ChangeMusic(37); -- the 1.x duty theme
end

function onUpdate(tick, area)
	questBattle.update(tick, area, FIGHT_LIMIT_SECONDS, loseEtc2g3Fight);
end

function onAbort(player, contentArea, director)
	questBattle.abort(player);
end

function onDestroy()
end
