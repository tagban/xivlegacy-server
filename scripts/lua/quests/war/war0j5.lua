require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	Proof is in the Pudding
Code:	War0j5
Id:		111205
Prereq: War0j4, Warrior 45

The cuirass Curious Gorge kept will not answer him. He proposes a contest
for the whole set: the first to fell Audhumbla, deep in the caves of Iron
Lake in the La Noscea highlands, learns the chronicles' last technique and
keeps the armor (processEventCURIOUS_GORGEStart). Walking into the beast's
cave starts the fight (SimpleContentWar0j501); the quest ends there, away
from any NPC (onJobQuestComplete*).

The client has no battle npc named Audhumbla; a great buffalo (2100801)
stands in. The cave is placed by Bronze Lake in Upper La Noscea.

]]

local SEQ_000 = 0;	-- Slay Audhumbla.

local ENPC_CURIOUS_GORGE	= 1060028;
local CAVE_TRIGGER			= 1090908;

local FIGHT = { 135, -320.0, 52.6, -1820.0, 3.1 };

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_CURIOUS_GORGE, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ENPC_CURIOUS_GORGE);
		quest:SetENpc(CAVE_TRIGGER, QFLAG_PUSH, false, true);
	end
end

function onTalk(player, quest, npc, eventName)
	if (npc.GetActorClassId() == ENPC_CURIOUS_GORGE) then
		if (quest:GetSequence() == SEQ_ACCEPT) then
			-- The contest for the armor (1 = accepted).
			if (callClientFunction(player, "delegateEvent", player, quest, "processEventCURIOUS_GORGEStart") == 1) then
				player:AcceptQuest(quest);
			end
		else
			-- Audhumbla's hide.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000");
		end
	end
	player:EndEvent();
end

function onPush(player, quest, npc)
	if (quest:GetSequence() == SEQ_000 and npc:GetActorClassId() == CAVE_TRIGGER) then
		questBattle.start(player, "War0j501", FIGHT, "Quest/SimpleQuestBattle/QuestDirectorWar0j101");
		return;
	end
	player:EndEvent();
end

-- Audhumbla is down.
jobQuest.registerFight(111205, SEQ_000, function(player, quest)
	jobQuest.completeAway(player, quest);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end);

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
