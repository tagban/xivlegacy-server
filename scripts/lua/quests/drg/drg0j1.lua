require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	Eye of the Dragon
Code:	Drg0j1
Id:		111321
Prereq: Lancer 30, a second class at 15 (Job 1: the dragoon)

Haurtefert of the Wood Wailers asks you to help an Ishgardian knight, Ser
Alberic, who waits at the Gates of Judgement in Coerthas
(processEventStart). Alberic tells you the Eye, Ishgard's great relic, was
stolen by the dragoon Estinien, who hides near Camp Nine Ivies in the East
Shroud; he asks you to clear the beasts there for the search
(processEventAlberic). Walking into their ground starts the fight
(SimpleContentDrg0j101). In the middle of it a dragoon in black appears and
a strange light drives him off (processEventNQ). Alberic explains that the
Eye has chosen you and gives you the Soul of the Dragoon (processEventClear,
processEventKokuti).

Ser Alberic (1060040) had no class script and no spawn; he stands by the
road west of Camp Glory. Dreadwolves stand in for the beasts.

]]

local SEQ_000	= 0;	-- Meet Ser Alberic at the Gates of Judgement.
local SEQ_010	= 10;	-- Clear the beasts near Camp Nine Ivies.
local SEQ_020	= 20;	-- Return to Ser Alberic.

local ENPC_HAURTEFERT	= 1000569;
local ENPC_ALBERIC		= 1060040;
local CULL_TRIGGER		= 1090956;

local JOB_DRAGOON = 19;

local FIGHT = { 151, 1680.0, 26.6, -900.0, 1.6 };

local TALKS = {
	[SEQ_000] = { [ENPC_HAURTEFERT] = "processEventStartAfter" },
	[SEQ_010] = { [ENPC_HAURTEFERT] = "processEventStartAfter", [ENPC_ALBERIC] = "processEventAlbericAfter" },
	[SEQ_020] = { [ENPC_HAURTEFERT] = "processEventStartAfter" },
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_HAURTEFERT, QFLAG_TALK);
		return;
	end
	jobQuest.chatterMarkers(quest, TALKS, sequence);
	if (sequence == SEQ_000) then
		quest:SetENpc(ENPC_ALBERIC, QFLAG_TALK);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(CULL_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(ENPC_ALBERIC, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_HAURTEFERT) then
		-- A favor for an Ishgardian knight (1 = accepted).
		if (callClientFunction(player, "delegateEvent", player, quest, "processEventStart") == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and npcClassId == ENPC_ALBERIC) then
		-- The stolen Eye, and the beasts near Camp Nine Ivies.
		callClientFunction(player, "delegateEvent", player, quest, "processEventAlberic");
		quest:StartSequence(SEQ_010);
	elseif (seq == SEQ_020 and npcClassId == ENPC_ALBERIC) then
		-- The Eye's choice: the Soul of the Dragoon.
		callClientFunction(player, "delegateEvent", player, quest, "processEventClear");
		jobQuest.giveSoulCrystal(player, JOB_DRAGOON);
		callClientFunction(player, "delegateEvent", player, quest, "processEventKokuti", jobQuest.SOUL_CRYSTAL[JOB_DRAGOON]);
		player:CompleteQuest(quest);
	else
		jobQuest.chatter(player, quest, TALKS, seq, npcClassId);
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc)
	if (quest:GetSequence() == SEQ_010 and npc:GetActorClassId() == CULL_TRIGGER) then
		questBattle.start(player, "Drg0j101", FIGHT, "Quest/SimpleQuestBattle/QuestDirectorWar0j101");
		return;
	end
	player:EndEvent();
end

-- The beasts are down; the dragoon in black, and the light.
jobQuest.registerFight(111321, SEQ_010, function(player, quest)
	callClientFunction(player, "delegateEvent", player, quest, "processEventNQ");
	quest:StartSequence(SEQ_020);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end);

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
