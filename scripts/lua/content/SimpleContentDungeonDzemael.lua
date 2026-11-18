require ("dungeon")

-- A copy of the dungeon in zone 231 (dungeon.lua): its monsters, and in its
-- farthest chamber the magitek terminal that takes you back to the entrance
-- (the Grand Companies' Into the Dark quests, Com5x1; the guard tells of it).

function onCreate(player, contentArea, director)
	spawnDungeon(player, contentArea, director, 231);
	-- A member of the copy's content group, or the client won't talk to it.
	director:AddMember(contentArea:SpawnActor(1002062, "dzemael_terminal", 233.5, 130.7, 4.0, -1.57));
end

function onZoneIn(player, contentArea, director)
end

function onUpdate(tick, area)
end

function onAbort(player, contentArea, director)
end

function onDestroy()
end
