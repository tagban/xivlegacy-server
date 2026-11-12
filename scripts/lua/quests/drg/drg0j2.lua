require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	Lance of Fury
Code:	Drg0j2
Id:		111322
Prereq: Drg0j1, Dragoon 35

Ser Alberic tells of Haldrath and the Eye taken from Nidhogg, and of
dragons stirring of late. As training, he has you put down the bomb baron in
Cassiopeia Hollow, east of Camp Bloodshore (processEventALBERICStart).
Walking into its lair starts the fight (SimpleContentDrg0j201). The quest
ends there, away from any NPC (onJobQuestComplete*).

]]

local SEQ_000 = 0;	-- Slay the bomb baron in Cassiopeia Hollow.

local ENPC_ALBERIC	= 1060040;
local FIGHT_TRIGGER		  = 1090957;

local FIGHT = { 132, 1343.5, -54.4, -862.0, 0.0 };

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_ALBERIC, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ENPC_ALBERIC);
		quest:SetENpc(FIGHT_TRIGGER, QFLAG_PUSH, false, true);
	end
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	if (quest:GetSequence() == SEQ_ACCEPT) then
		if (npcClassId == ENPC_ALBERIC) then
			-- The next lesson (1 = accepted).
			if (callClientFunction(player, "delegateEvent", player, quest, "processEventALBERICStart") == 1) then
				player:AcceptQuest(quest);
			end
		end
	elseif (npcClassId == ENPC_ALBERIC) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_ALBERICS");
	end
	player:EndEvent();
end

function onPush(player, quest, npc)
	if (quest:GetSequence() == SEQ_000 and npc:GetActorClassId() == FIGHT_TRIGGER) then
		questBattle.start(player, "Drg0j201", FIGHT, "Quest/SimpleQuestBattle/QuestDirectorWar0j101");
		return;
	end
	player:EndEvent();
end

-- The bomb baron is down.
jobQuest.registerFight(111322, SEQ_000, function(player, quest)
	jobQuest.completeAway(player, quest);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end);

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
