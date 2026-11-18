require ("global")
require ("questbattle")

-- Unfading Scars (Drg0j3): Spitfire at Millers' Glade.
-- When every foe is down the content has no hostiles left, which fires
-- "battleComplete" to the director (jobQuest.runFightDirector).

local BNPCS = { 3753 };
local FIGHT_LIMIT_SECONDS = 480;
-- Where a loss sets the player down (outside the trigger circle).
local SPOT = { 145, 1915.0, 125.3, 700.0, 3.1 };

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
