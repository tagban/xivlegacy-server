require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	Brother from Another Mother
Code:	Mnk0j1
Id:		111221
Prereq: Pugilist 30, a second class at 15 (Job 1: the monk)

Gagaruna of the Platinum Mirage needs a guard for Professor Erik, a
scholar of old battlefields and one of the guild's best-paying debtors
(processEventGAGARUNAStart). Erik waits at Ul'dah's chocobo stables and
sends you to clear the runagate imps west of Mythril Pit T.8, south of
Camp Drybone (processEvent005). Walking into the imps' ground starts the
fight (SimpleContentMnk0j101). With the imps down, Widargelt finds you:
the old battlefield has opened your chakra, and he hands you the Soul of
the Monk (processEvent010 cutscene, processEvent010_2/3_system).

Erik (1060033) and Widargelt (1060032) had no class script and no spawn.
The client script has no point markers for this quest.

]]

local SEQ_000	= 0;	-- Meet Professor Erik at the chocobo stables.
local SEQ_010	= 10;	-- Slay the runagate imps west of Mythril Pit T.8.

local ENPC_GAGARUNA	= 1000862;
local ENPC_ERIK		= 1060033;
local IMP_TRIGGER	= 1090910;

local JOB_MONK = 15;

local FIGHT = { 171, 1160.7, 279.5, -421.3, 1.6 };

local TALKS = {
	[SEQ_000] = { [ENPC_GAGARUNA] = "processEvent000_1" },
	[SEQ_010] = { [ENPC_GAGARUNA] = "processEvent000_1", [ENPC_ERIK] = "processEvent005_1" },
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_GAGARUNA, QFLAG_TALK);
		return;
	end
	jobQuest.chatterMarkers(quest, TALKS, sequence);
	if (sequence == SEQ_000) then
		quest:SetENpc(ENPC_ERIK, QFLAG_TALK);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(IMP_TRIGGER, QFLAG_PUSH, false, true);
	end
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_GAGARUNA) then
		-- Guard the Professor (1 = accepted).
		if (callClientFunction(player, "delegateEvent", player, quest, "processEventGAGARUNAStart") == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and npcClassId == ENPC_ERIK) then
		-- Erik's method, Sil'dih, and the imps west of Mythril Pit T.8.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent005");
		quest:StartSequence(SEQ_010);
	else
		jobQuest.chatter(player, quest, TALKS, seq, npcClassId);
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc)
	if (quest:GetSequence() == SEQ_010 and npc:GetActorClassId() == IMP_TRIGGER) then
		questBattle.start(player, "Mnk0j101", FIGHT, "Quest/SimpleQuestBattle/QuestDirectorWar0j101");
		return;
	end
	player:EndEvent();
end

-- The imps are down: Widargelt, the open chakra, the Soul of the Monk.
jobQuest.registerFight(111221, SEQ_010, function(player, quest)
	callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
	jobQuest.giveSoulCrystal(player, JOB_MONK);
	callClientFunction(player, "delegateEvent", player, quest, "processEvent010_2_system", jobQuest.SOUL_CRYSTAL[JOB_MONK]);
	callClientFunction(player, "delegateEvent", player, quest, "processEvent010_3_system");
	player:CompleteQuest(quest);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end);

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
