require ("global")
require ("questbattle")
require ("quests/etc/etc1u8")

-- Traumaturgy (Etc1u8): Theda's captors below the mesa northeast of Halatali.
-- When every foe is down the content has no hostiles left, which fires
-- "battleComplete" to QuestDirectorEtc1u801 (see questbattle.lua).

BNPCS = { 4086, 4087, 4088 };
FIGHT_LIMIT_SECONDS = 360;

function onCreate(player, contentArea, director)
	questBattle.create(player, contentArea, director, BNPCS);
end

function onZoneIn(player, contentArea, director)
	player:ChangeMusic(37); -- the 1.x duty theme
end

function onUpdate(tick, area)
	questBattle.update(tick, area, FIGHT_LIMIT_SECONDS, loseEtc1u8Fight);
end

function onAbort(player, contentArea, director)
	questBattle.abort(player);
end

function onDestroy()
end
