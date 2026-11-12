require ("global")
require ("questbattle")

-- Pld0j6: the Monetarists' cohort southeast of Camp Bluefog (Sultansworn elites stand in).
-- When every foe is down the content has no hostiles left, which fires
-- "battleComplete" to the director (jobQuest.runFightDirector).

local BNPCS = { 3740, 3741, 3742 };
local FIGHT_LIMIT_SECONDS = 600;
-- Where a loss sets the player down (outside the trigger circle).
local SPOT = { 173, -165.8, 280, -1698, 0 };

function onCreate(player, contentArea, director)
	questBattle.create(player, contentArea, director, BNPCS);
end

function onZoneIn(player, contentArea, director)
	player:ChangeMusic(37); -- the 1.x duty theme
end

function onUpdate(tick, area)
	questBattle.update(tick, area, FIGHT_LIMIT_SECONDS, function(player, timedOut)
		questBattle.leave(player, SPOT);
	end);
end

function onAbort(player, contentArea, director)
	questBattle.abort(player);
end

function onDestroy()
end
