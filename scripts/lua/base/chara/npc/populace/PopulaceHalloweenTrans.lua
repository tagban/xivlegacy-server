require ("global")
require ("quests/spl/allsaints")

--[[

PopulaceHalloweenTrans Script

A trickster imp disguised as a townsperson ("suspicious ...") during All
Saints' Wake. Spawns only while the event runs, at night, Eorzean time
(settings/events.toml). Riddles and payouts: quests/spl/allsaints.lua.

]]

function init(npc)
	return false, false, 0, 0;
end

function onEventStarted(player, npc, triggerName)
	allSaintsImpTalk(player, npc);
end
