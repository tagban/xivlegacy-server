require ("global")
require ("allyfight")
require ("quests/etc/etc2i2")

-- Blood Price (Etc2i2): the Lambs of Dalamud at Gwyr-Aen, four Lunatic
-- Lambs two at a time and then the Lunatic Shepherd (Gamer Escape).

function onCreate(player, contentArea, director)
	allyFight.create(ETC2I2_FIGHT, player, contentArea, director);
end

function onUpdate(tick, area)
	allyFight.update(ETC2I2_FIGHT, tick, area, loseEtc2i2Fight);
end

function onAbort(player, contentArea, director)
	allyFight.abort(player);
end

function onDestroy()
end
