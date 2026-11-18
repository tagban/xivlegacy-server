require ("global")
require ("questbattle")

-- Requiem for the Fallen (Brd0j6): Ixal at Griffin Crossing.
-- When every foe is down the content has no hostiles left, which fires
-- "battleComplete" to the director (jobQuest.runFightDirector).

local BNPCS = { 3748, 3749 };
local FIGHT_LIMIT_SECONDS = 480;
-- Where a loss sets the player down (outside the trigger circle).
local SPOT = { 152, -1255.0, 20.0, -2245.0, 1.6 };

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
