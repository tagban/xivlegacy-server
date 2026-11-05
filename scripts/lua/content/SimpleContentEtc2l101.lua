require ("global")
require ("questbattle")
require ("quests/etc/etc2l1")

-- Moonstruck (Etc2l1): two aldgoat nannies, a moraby mole and a black bat on the road from Wineport to Bloodshore.
-- When every foe is down the content has no hostiles left, which fires
-- "battleComplete" to QuestDirectorEtc2l101 (see questbattle.lua).

BNPCS = { 4116, 4117, 4118, 4119 };
FIGHT_LIMIT_SECONDS = 360;

function onCreate(player, contentArea, director)
	questBattle.create(player, contentArea, director, BNPCS);
end

function onZoneIn(player, contentArea, director)
	player:ChangeMusic(37); -- the 1.x duty theme
end

function onUpdate(tick, area)
	questBattle.update(tick, area, FIGHT_LIMIT_SECONDS, loseEtc2l1Fight);
end

function onAbort(player, contentArea, director)
	questBattle.abort(player);
end

function onDestroy()
end
