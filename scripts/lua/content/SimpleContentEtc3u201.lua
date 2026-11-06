require ("global")
require ("questbattle")
require ("quests/etc/etc3u2")

-- There Might Be Blood (Etc3u2): the Coliseum yarzon at Little Ala Mhigo.
-- When every foe is down the content has no hostiles left, which fires
-- "battleComplete" to QuestDirectorEtc3u201 (see questbattle.lua).

BNPCS = { 4076 };
FIGHT_LIMIT_SECONDS = 360;

function onCreate(player, contentArea, director)
	questBattle.create(player, contentArea, director, BNPCS);
end

function onZoneIn(player, contentArea, director)
	player:ChangeMusic(37); -- the 1.x duty theme
end

function onUpdate(tick, area)
	questBattle.update(tick, area, FIGHT_LIMIT_SECONDS, loseEtc3u2Fight);
end

function onAbort(player, contentArea, director)
	questBattle.abort(player);
end

function onDestroy()
end
