require ("global")
require ("questbattle")

-- How to Quit You (War0j6): Curious Gorge, lost to his inner beast, at the Silver Bazaar.
-- When every foe is down the content has no hostiles left, which fires
-- "battleComplete" to the director (jobQuest.runFightDirector).

local BNPCS = { 3709 };
local FIGHT_LIMIT_SECONDS = 480;
-- Where a loss sets the player down (outside the trigger circle).
local SPOT = { 172, -1395.0, 56.0, 561.0, 1.6 };

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
