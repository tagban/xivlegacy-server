require ("global")
require ("quest")
require ("jobquest")

--[[

Quest Script

Name:	The Voidgate Breathes Gloomy
Code:	Blm0j4
Id:		111264
Prereq: Blm0j3, Black Mage 45

The Ixal Dozol Meloc says the Gloom from the Voidgate stirs at the power
woken in you. Mages of old sealed an ancient black magic in a mossy stone
stela in the West Shroud, northwest of Turning Leaf; raise the gem there
(processEventDOZOLMELOCStart). At the stela the magic answers
(processEvent000_SEKIHI, processEvent005), and the quest ends there, away
from any NPC (onJobQuestComplete*).

Dozol Meloc's hint speaks of a beast lurking by the stela, but the client
names no foe for this quest and its script has no fight; none is spawned.

]]

local SEQ_000 = 0;	-- Find the stela northwest of Turning Leaf.

local ENPC_LALAI		= 1060034;
local ENPC_KAZAGG_CHAH	= 1060036;
local ENPC_DOZOL_MELOC	= 1060037;
local ENPC_DA_ZA		= 1060038;
local STELA				= 1090932;

local TALKS = {
	[SEQ_000] = {
		[ENPC_DOZOL_MELOC] = "processEvent000_DOZOLMELOC",
		[ENPC_LALAI] = "processEvent000_LALAI",
		[ENPC_KAZAGG_CHAH] = "processEvent000_KAZAGGCHAH",
		[ENPC_DA_ZA] = "processEvent000_DAZA",
	},
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_DOZOL_MELOC, QFLAG_TALK);
		return;
	end
	jobQuest.chatterMarkers(quest, TALKS, sequence);
	quest:SetENpc(STELA, QFLAG_PUSH, false, true);
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();
	if (seq == SEQ_ACCEPT) then
		if (npcClassId == ENPC_DOZOL_MELOC) then
			-- The stela in the Shroud (1 = accepted).
			if (callClientFunction(player, "delegateEvent", player, quest, "processEventDOZOLMELOCStart") == 1) then
				player:AcceptQuest(quest);
			end
		end
	else
		jobQuest.chatter(player, quest, TALKS, seq, npcClassId);
	end
	player:EndEvent();
end

function onPush(player, quest, npc)
	if (quest:GetSequence() == SEQ_000 and npc:GetActorClassId() == STELA) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_SEKIHI");
		callClientFunction(player, "delegateEvent", player, quest, "processEvent005");
		jobQuest.completeAway(player, quest);
	end
	player:EndEvent();
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
