require ("global")
require ("questbattle")
require ("quests/etc/etc2g5")

-- Losing One's Thread (Etc2g5): the goblins east of Camp Tranquil.
-- When every foe is down the content has no hostiles left, which fires
-- "battleComplete" to QuestDirectorEtc2g501 (see questbattle.lua).

BNPCS = { 4073, 4074, 4075 };
FIGHT_LIMIT_SECONDS = 360;

function onCreate(player, contentArea, director)
	questBattle.create(player, contentArea, director, BNPCS);
end

function onZoneIn(player, contentArea, director)
	player:ChangeMusic(37); -- the 1.x duty theme
end

function onUpdate(tick, area)
	questBattle.update(tick, area, FIGHT_LIMIT_SECONDS, loseEtc2g5Fight);
end

function onAbort(player, contentArea, director)
	questBattle.abort(player);
end

function onDestroy()
end
