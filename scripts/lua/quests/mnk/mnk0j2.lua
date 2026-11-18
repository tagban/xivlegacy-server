require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	Insulted Intelligence
Code:	Mnk0j2
Id:		111222
Prereq: Mnk0j1, Monk 35

Professor Erik hands you an aetheriometer and sends you south of Cedarwood
in Lower La Noscea to measure an old battlefield, once the beast Gluttonous
Gertrude is out of the way (processEventERIKStart). Walking into her
ground starts the fight (SimpleContentMnk0j201). The quest ends there,
away from any NPC (onJobQuestComplete*).

]]

local SEQ_000 = 0;	-- Slay Gluttonous Gertrude south of Cedarwood.

local ENPC_ERIK			= 1060033;
local ENPC_WIDARGELT	= 1060032;
local GERTRUDE_TRIGGER	= 1090911;

local FIGHT = { 128, 636.3, 45.8, 245.8, -1.6 };

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_ERIK, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ENPC_ERIK);
		quest:SetENpc(ENPC_WIDARGELT);
		quest:SetENpc(GERTRUDE_TRIGGER, QFLAG_PUSH, false, true);
	end
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	if (quest:GetSequence() == SEQ_ACCEPT) then
		if (npcClassId == ENPC_ERIK) then
			-- The aetheriometer, and Gertrude (1 = accepted).
			if (callClientFunction(player, "delegateEvent", player, quest, "processEventERIKStart") == 1) then
				player:AcceptQuest(quest);
			end
		end
	elseif (npcClassId == ENPC_ERIK) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000");
	elseif (npcClassId == ENPC_WIDARGELT) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_1");
	end
	player:EndEvent();
end

function onPush(player, quest, npc)
	if (quest:GetSequence() == SEQ_000 and npc:GetActorClassId() == GERTRUDE_TRIGGER) then
		questBattle.start(player, "Mnk0j201", FIGHT, "Quest/SimpleQuestBattle/QuestDirectorWar0j101");
		return;
	end
	player:EndEvent();
end

-- Gertrude is down; the measurement is taken.
jobQuest.registerFight(111222, SEQ_000, function(player, quest)
	jobQuest.completeAway(player, quest);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end);

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
