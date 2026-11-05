require ("global")
require ("questbattle")
require ("quests/etc/etc2u0")

-- The Unheard Horizon (Etc2u0): two coblyns, a spriggan and a feral dodo on the outskirts of Camp Horizon.
-- When every foe is down the content has no hostiles left, which fires
-- "battleComplete" to QuestDirectorEtc2u001 (see questbattle.lua).

BNPCS = { 4100, 4101, 4102, 4103 };
FIGHT_LIMIT_SECONDS = 360;

function onCreate(player, contentArea, director)
	questBattle.create(player, contentArea, director, BNPCS);
end

function onZoneIn(player, contentArea, director)
	player:ChangeMusic(37); -- the 1.x duty theme
end

function onUpdate(tick, area)
	questBattle.update(tick, area, FIGHT_LIMIT_SECONDS, loseEtc2u0Fight);
end

function onAbort(player, contentArea, director)
	questBattle.abort(player);
end

function onDestroy()
end
