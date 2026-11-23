require ("global")

-- GM !cutscene <name> (map-server/src/processor/cutscene.rs). The server
-- spawns this director on the typer's client as a raid director
-- (/Director/InstanceRaid/...), whose client class has
-- cutSceneEvent(name): fade out, play client/cut/<name> where you stand,
-- fade back in. The kick hands the name over as the event's first argument.

function init()
	return "/Director/InstanceRaid/InstanceRaidLesserIfrit";
end

function onEventStarted(player, director, eventName, cutName, ...)
	if (type(cutName) == "string" and cutName ~= "") then
		callClientFunction(player, "cutSceneEvent", cutName);
	end
	player:EndEvent();
end

function main()
end
