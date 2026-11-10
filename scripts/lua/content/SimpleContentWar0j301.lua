require ("global")
require ("questbattle")

-- Curious Gorge Goes to the Bazaar (War0j3): the canyon condors north of the Silver Bazaar.
-- When every foe is down the content has no hostiles left, which fires
-- "battleComplete" to the director (jobQuest.runFightDirector).

local BNPCS = { 3705, 3706, 3707 };
local FIGHT_LIMIT_SECONDS = 360;
-- Where a loss sets the player down (outside the trigger circle).
local SPOT = { 172, -1340.0, 56.0, 452.0, 3.1 };

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
