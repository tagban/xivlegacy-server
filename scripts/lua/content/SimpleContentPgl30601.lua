require ("global")
require ("questbattle")
require ("quests/pgl/pgl306")

-- Two Sides to Every Chip (Pgl306): a thaumaturge of Arrzaneth Ossuary and
-- her doppelganger. When both are down the content has no hostiles left,
-- which fires "battleComplete" to QuestDirectorPgl30601 (see questbattle.lua).

BNPCS = { 4044, 4045 };
FIGHT_LIMIT_SECONDS = 360;

function onCreate(player, contentArea, director)
	questBattle.create(player, contentArea, director, BNPCS);
end

function onZoneIn(player, contentArea, director)
	player:ChangeMusic(37); -- the 1.x duty theme
end

function onUpdate(tick, area)
	questBattle.update(tick, area, FIGHT_LIMIT_SECONDS, losePgl306Fight);
end

function onAbort(player, contentArea, director)
	questBattle.abort(player);
end

function onDestroy()
end
