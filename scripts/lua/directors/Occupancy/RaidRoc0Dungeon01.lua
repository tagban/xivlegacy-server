require ("global")

-- The client's own director for this dungeon (dungeon.lua).

function init()
	return "/Director/Occupancy/RaidRoc0Dungeon01";
end

-- The entry notice. Without the director's relogin (its Now Loading fade-in)
-- the client stays in the entry event and won't talk to anyone, inside or
-- after leaving. relogin's last argument true skips the dungeon's timer
-- widget, which has no timer data from this server yet and would crash the
-- client.
function onEventStarted(player, actor, triggerName)
	callClientFunction(player, "delegateEvent", player, actor, "relogin", true);
	player:EndEvent();
end

function main()
end
