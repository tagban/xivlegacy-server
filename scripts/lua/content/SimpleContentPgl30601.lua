require ("global")
require ("questbattle")
require ("quests/pgl/pgl306")

-- Two Sides to Every Chip (Pgl306): a thaumaturge of Arrzaneth Ossuary and
-- her doppelganger. When both are down the content has no hostiles left,
-- which fires "battleComplete" to QuestDirectorPgl30601 (see questbattle.lua).
--
-- Balance (level 36 Pugilist, 1332 HP in level-36 gear): the thaumaturge
-- (group 30452, level 36, 1100 HP) lands spells for about 230. The
-- doppelganger (30453) is a weaker copy, level 30 with 400 HP, whose spells
-- land for about 90. Two level-36 casters (600 HP for the copy) killed an
-- active Pugilist in 60-90 s, before half their HP was gone.

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
