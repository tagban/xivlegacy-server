require ("dungeon")

-- A copy of the dungeon in zone 159 (dungeon.lua): its monsters, and in the
-- last chamber (by the lantern huts) the imperial device with the moogles
-- it called there and Seedseer A-Ruhn-Senna, who came to save them. The
-- Grand Companies' Imperial Devices quests (Com5x0)
-- give them their talk; the device takes you back to the entrance.

function onCreate(player, contentArea, director)
	spawnDungeon(player, contentArea, director, 159);
	-- Members of the copy's content group, or the client won't talk to them.
	director:AddMember(contentArea:SpawnActor(1002063, "totorak_transmitter", 1471.0, -59.0, 627.5, 0.0));
	director:AddMember(contentArea:SpawnActor(1001938, "totorak_kupcha_kupa", 1470.0, -59.0, 634.0, 0.0));
	director:AddMember(contentArea:SpawnActor(1001937, "totorak_pukni_pakk", 1467.0, -59.0, 632.5, 0.6));
	director:AddMember(contentArea:SpawnActor(1001936, "totorak_pukno_poki", 1473.5, -59.0, 632.5, -0.6));
	director:AddMember(contentArea:SpawnActor(1001571, "totorak_a_ruhn_senna", 1475.5, -59.0, 629.5, -0.9));
end

function onZoneIn(player, contentArea, director)
end

function onUpdate(tick, area)
end

function onAbort(player, contentArea, director)
end

function onDestroy()
end
