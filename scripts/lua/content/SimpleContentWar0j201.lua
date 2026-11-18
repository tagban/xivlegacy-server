require ("global")
require ("questbattle")

-- Embracing the Beast (War0j2): Sirocco and his mate in Humblehearth.
-- When every foe is down the content has no hostiles left, which fires
-- "battleComplete" to the director (jobQuest.runFightDirector).

local BNPCS = { 3703, 3704 };
local FIGHT_LIMIT_SECONDS = 360;
-- Where a loss sets the player down (outside the trigger circle).
local SPOT = { 150, -328.0, 1.5, -628.0, -0.9 };

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
