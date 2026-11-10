require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	Embracing the Beast
Code:	War0j2
Id:		111202
Prereq: War0j1, Warrior 35

Curious Gorge's work on the chronicles is slow, but he has a second
exercise for you: hunt the beast Sirocco in Humblehearth, in the Central
Shroud (processEventCURIOUS_GORGEStart). Sirocco hunts with his mate;
walking into their hunting ground starts the fight (SimpleContentWar0j201).
The quest ends there, away from any NPC (onJobQuestComplete*).

]]

local SEQ_000 = 0;	-- Slay Sirocco in Humblehearth.

local ENPC_CURIOUS_GORGE	= 1060028;
local HUNT_TRIGGER			= 1090901;

local FIGHT = { 150, -328.0, 1.5, -628.0, -0.9 };

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
		quest:SetENpc(HUNT_TRIGGER, QFLAG_PUSH, false, true);
	end
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (npcClassId == ENPC_CURIOUS_GORGE) then
		if (seq == SEQ_ACCEPT) then
			-- The armor of the chronicles, and Sirocco (1 = accepted).
			if (callClientFunction(player, "delegateEvent", player, quest, "processEventCURIOUS_GORGEStart") == 1) then
				player:AcceptQuest(quest);
			end
			player:EndEvent();
			return;
		end
		-- How Sirocco and his mate hunt.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000");
	end
	player:EndEvent();
end

function onPush(player, quest, npc)
	if (quest:GetSequence() == SEQ_000 and npc:GetActorClassId() == HUNT_TRIGGER) then
		questBattle.start(player, "War0j201", FIGHT, "Quest/SimpleQuestBattle/QuestDirectorWar0j101");
		return;
	end
	player:EndEvent();
end

-- Sirocco and his mate are down.
jobQuest.registerFight(111202, SEQ_000, function(player, quest)
	jobQuest.completeAway(player, quest);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end);

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
