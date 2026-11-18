require ("dungeon")

-- A copy of the dungeon in zone 246 (dungeon.lua): its monsters, and in the
-- last chamber the Darklight Raiders' resting place, where A Light in the
-- Dark (Etc200) has you lay Sibold's bouquet.

function onCreate(player, contentArea, director)
	spawnDungeon(player, contentArea, director, 246);
	-- Members of the copy's content group, or the client won't push them.
	-- By the Chimera's chamber: the layout's own chimerabeya room, west of
	-- it, is walled off in the client (STUCK.md), so the tomb stands just
	-- outside the boss room, where players can reach it.
	director:AddMember(contentArea:SpawnActor(1090616, "cutters_raiders_tomb", -1330.0, 249.3, -1840.0, 0.0));
end

function onZoneIn(player, contentArea, director)
end

function onUpdate(tick, area)
end

function onAbort(player, contentArea, director)
end

function onDestroy()
end
