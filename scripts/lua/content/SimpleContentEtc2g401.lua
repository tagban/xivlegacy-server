require ("global")
require ("questbattle")
require ("quests/etc/etc2g4")

-- To Deskunk A Beer (Etc2g4): sourleaf roselets east of Humblehearth.
-- When every foe is down the content has no hostiles left, which fires
-- "battleComplete" to QuestDirectorEtc2g401 (see questbattle.lua).

BNPCS = { 4140, 4141, 4142 };
FIGHT_LIMIT_SECONDS = 360;

function onCreate(player, contentArea, director)
	questBattle.create(player, contentArea, director, BNPCS);
end

function onZoneIn(player, contentArea, director)
	player:ChangeMusic(37); -- the 1.x duty theme
end

function onUpdate(tick, area)
	questBattle.update(tick, area, FIGHT_LIMIT_SECONDS, loseEtc2g4Fight);
end

function onAbort(player, contentArea, director)
	questBattle.abort(player);
end

function onDestroy()
end
