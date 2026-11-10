require ("global")
require ("questbattle")

-- Pride and Duty (War0j1): three antling workers at the nest north of Curious Gorge's cave.
-- When every foe is down the content has no hostiles left, which fires
-- "battleComplete" to the director (jobQuest.runFightDirector).

local BNPCS = { 3700, 3701, 3702 };
local FIGHT_LIMIT_SECONDS = 360;
-- Where a loss sets the player down (outside the trigger circle).
local SPOT = { 172, -1262.0, 55.7, -132.0, 0.6 };

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
