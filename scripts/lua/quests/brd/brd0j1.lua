require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	A Song of Bards and Bowmen
Code:	Brd0j1
Id:		111301
Prereq: Archer 30, a second class at 15 (Job 1: the bard)

Georjeaux of the Quiver's Hold says Jehantel the Godsbow, the archer
turned bard, is back in the Twelveswood, camped north of Camp Tranquil; he
turns away pupils of the bow and offers only poetry
(processEventGEORJEAUXStart). You take him up on the poetry
(processEvent000), and he sends you to the moogle Pukno Poki in a cave east
of Camp Tranquil. A Qiqirn shirrer stole the charm Pukno Poki meant for
Jehantel (processEvent005); walking into its hideout starts the fight
(SimpleContentBrd0j101). Back with Jehantel, the charm turns out to be the
Soul of the Bard (processEvent015, processEventJob).

Jehantel's camp and Pukno Poki's cave aren't recorded; they stand north
and east of Camp Tranquil.

]]

local SEQ_000	= 0;	-- Find Jehantel north of Camp Tranquil.
local SEQ_005	= 5;	-- Speak to Pukno Poki east of Camp Tranquil.
local SEQ_010	= 10;	-- Take back the charm from the Qiqirn shirrer.
local SEQ_015	= 15;	-- Bring the charm to Jehantel.

local ENPC_GEORJEAUX	= 1000830;
local ENPC_JEHANTEL		= 1060039;
local ENPC_PUKNO_POKI	= 1001936;
local SHIRRER_TRIGGER	= 1090947;

local JOB_BARD = 18;

local FIGHT = { 154, 845.0, -12.6, 1080.0, 1.6 };

local TALKS = {
	[SEQ_000] = { [ENPC_GEORJEAUX] = "processEvent000_GEORJEAUX" },
	[SEQ_005] = { [ENPC_GEORJEAUX] = "processEvent000_GEORJEAUX", [ENPC_JEHANTEL] = "processEvent005_JEHANTEL" },
	[SEQ_010] = { [ENPC_JEHANTEL] = "processEvent005_JEHANTEL", [ENPC_PUKNO_POKI] = "processEvent010_PUKNOPOKI" },
	[SEQ_015] = { [ENPC_PUKNO_POKI] = "processEvent010_PUKNOPOKI" },
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_GEORJEAUX, QFLAG_TALK);
		return;
	end
	jobQuest.chatterMarkers(quest, TALKS, sequence);
	if (sequence == SEQ_000) then
		quest:SetENpc(ENPC_JEHANTEL, QFLAG_TALK);
	elseif (sequence == SEQ_005) then
		quest:SetENpc(ENPC_PUKNO_POKI, QFLAG_TALK);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(SHIRRER_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_015) then
		quest:SetENpc(ENPC_JEHANTEL, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_GEORJEAUX) then
		-- Jehantel the Godsbow is back (1 = accepted).
		if (callClientFunction(player, "delegateEvent", player, quest, "processEventGEORJEAUXStart") == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and npcClassId == ENPC_JEHANTEL) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000");
		quest:StartSequence(SEQ_005);
	elseif (seq == SEQ_005 and npcClassId == ENPC_PUKNO_POKI) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent005");
		quest:StartSequence(SEQ_010);
	elseif (seq == SEQ_015 and npcClassId == ENPC_JEHANTEL) then
		-- The charm: the Soul of the Bard.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent015");
		jobQuest.giveSoulCrystal(player, JOB_BARD);
		callClientFunction(player, "delegateEvent", player, quest, "processEventJob", jobQuest.SOUL_CRYSTAL[JOB_BARD]);
		player:CompleteQuest(quest);
	else
		jobQuest.chatter(player, quest, TALKS, seq, npcClassId);
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc)
	if (quest:GetSequence() == SEQ_010 and npc:GetActorClassId() == SHIRRER_TRIGGER) then
		questBattle.start(player, "Brd0j101", FIGHT, "Quest/SimpleQuestBattle/QuestDirectorWar0j101");
		return;
	end
	player:EndEvent();
end

-- The shirrer is down and the charm is back.
jobQuest.registerFight(111301, SEQ_010, function(player, quest)
	attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
	quest:StartSequence(SEQ_015);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end);

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
