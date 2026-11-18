require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	Unfading Scars
Code:	Drg0j3
Id:		111323
Prereq: Drg0j2, Dragoon 40

Ser Alberic tells how Nidhogg's last attack took his strength and left
Estinien an orphan of Ferndale. A young dragoon has fallen to a dragon near
Millers' Glade in the Coerthas eastern lowlands, and a spriggan called
Spitfire now haunts the place; Alberic asks you to slay it
(processEventALBERICStart). Walking into its ground starts the fight
(SimpleContentDrg0j301). The quest ends there, away from any NPC
(onJobQuestComplete*).

The client has no position for Millers' Glade; it stands east of Camp
Glory.

]]

local SEQ_000 = 0;	-- Slay Spitfire at Millers' Glade.

local ENPC_ALBERIC	= 1060040;
local FIGHT_TRIGGER		  = 1090958;

local FIGHT = { 145, 1915.0, 125.3, 700.0, 3.1 };

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
		questBattle.start(player, "Drg0j301", FIGHT, "Quest/SimpleQuestBattle/QuestDirectorWar0j101");
		return;
	end
	player:EndEvent();
end

-- Spitfire is down.
jobQuest.registerFight(111323, SEQ_000, function(player, quest)
	jobQuest.completeAway(player, quest);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end);

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
