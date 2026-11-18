require ("global")
require ("allyfight")
require ("quests/etc/etc3u1")

-- Quid Pro Quo (Etc3u1): the scavengers at the airship wreck northwest of
-- Ul'dah, four Unsavory Characters coming two at a time (Gamer Escape).

function onCreate(player, contentArea, director)
	allyFight.create(ETC3U1_FIGHT, player, contentArea, director);
end

function onUpdate(tick, area)
	allyFight.update(ETC3U1_FIGHT, tick, area, loseEtc3u1Fight);
end

function onAbort(player, contentArea, director)
	allyFight.abort(player);
end

function onDestroy()
end
