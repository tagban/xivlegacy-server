require ("global")
require ("quest")
require ("quests/spl/hatchgospel")

--[[

Quest Script

Name: 	The Dreamer's Gospel (Gridania)
Code: 	Spl0g1
Id: 	110794
Prereq: none (one Gospel per adventurer, quest_offers.rs). Seasonal: Hatching-tide
		(settings/events.toml).

Shared with the other cities in quests/spl/hatchgospel.lua; the story and the
numbers are in quests/spl/hatchingtide.lua.

]]

local CITY = HATCHINGTIDE.CITIES.gridania;

function onStart(player, quest) gospelStart(player, quest); end
function onFinish(player, quest) end
function onStateChange(player, quest, sequence) gospelStateChange(CITY, player, quest, sequence); end
function onTalk(player, quest, npc, eventName) gospelTalk(CITY, player, quest, npc); end
function onKillBNpc(player, quest, bnpc) gospelKill(player, quest, bnpc); end
function getJournalInformation(player, quest) return gospelJournal(player, quest); end
function getJournalMapMarkerList(player, quest) end
