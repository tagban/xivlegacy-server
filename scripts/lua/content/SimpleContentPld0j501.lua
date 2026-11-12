require ("global")
require ("questbattle")

-- Pld0j5: Jenlyns and his men at the parley northeast of Ul'dah.
-- When every foe is down the content has no hostiles left, which fires
-- "battleComplete" to the director (jobQuest.runFightDirector).

local BNPCS = { 3737, 3738, 3739 };
local FIGHT_LIMIT_SECONDS = 600;
-- Where a loss sets the player down (outside the trigger circle).
local SPOT = { 170, 33, 200.1, -482, 0 };

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
