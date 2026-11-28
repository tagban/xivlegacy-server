--[[

RequestInformationCommand Script

The journal's requests: "activegl" (a held regional leve's page) is
answered by the map server itself (#479). Anything else (the leve
history, "glHist") has no reply yet, so the event just ends.

--]]

function onEventStarted(player, actor, request)
	player:EndEvent();
end
