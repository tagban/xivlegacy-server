require ("global")
require ("quest")
require ("quests/spl/hatchdilemma")

--[[

Quest Script

Name: 	The Dreamer's Dilemma (Limsa Lominsa)
Code: 	Spl0l2
Id: 	110805
Prereq: any city's Dreamer's Gospel (quest_offers.rs). Seasonal: Hatching-tide
		(settings/events.toml).

Shared with the other cities in quests/spl/hatchdilemma.lua; the story and the
numbers are in quests/spl/hatchingtide.lua.

]]

local CITY = HATCHINGTIDE.CITIES.limsa;

function onStart(player, quest) dilemmaStart(player, quest); end
function onFinish(player, quest) end
function onStateChange(player, quest, sequence) dilemmaStateChange(CITY, player, quest, sequence); end
function onTalk(player, quest, npc, eventName) dilemmaTalk(CITY, player, quest, npc); end
function onKillBNpc(player, quest, bnpc) dilemmaKill(player, quest, bnpc); end
function getJournalInformation(player, quest) return dilemmaJournal(player, quest); end
function getJournalMapMarkerList(player, quest) end
