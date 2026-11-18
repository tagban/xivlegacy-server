require ("global")

-- The client's own director for this dungeon (dungeon.lua).

function init()
	return "/Director/InstanceRaid/InstanceRaidCuttersCry";
end

-- The entry notice. The client's raid director takes the copy's Now Loading
-- fade-in from reloginEvent (or startEvent); without it the fade's lock on
-- the player stays set, and the client then runs no command at all: Return
-- on the boss chest or any other NPC does nothing. reloginEvent(contentId,
-- startTime, finishTime, eventType, clearFlag): no start time means no
-- countdown, and clearFlag true leaves the timer widget closed (this server
-- sends no time limit).
function onEventStarted(player, actor, triggerName)
	callClientFunction(player, "reloginEvent", 0, 0, 0, 0, true);
	player:EndEvent();
end

function main()
end
