require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	Paladin's Pledge
Code:	Pld0j1
Id:		111281
Prereq: Gladiator 30, a second class at 15 (Job 1: the paladin)

Lulutsu of the Coliseum has news: for the first time the Sultansworn
elite will teach the paladin's arts to outsiders (processEventLULUTSUStart).
Their captain Jenlyns, by the Royal Promenade in the Hustings Strip, sets a
trial: slay the undead south of the Coffer & Coffin in Western Thanalan
(processEvent082). Walking among them starts the fight
(SimpleContentPld0j101). After the fight a free paladin hands you a
crystal for Jenlyns (processEvent015 cutscene). Jenlyns knows it for a
stolen, disgraced Soul of the Paladin, takes it, and gives you a true one
(processEvent020, processEventKokuti).

The undead's battle classes aren't named in the client; skeleton
swordbearers and a revenant stand in.

]]

local SEQ_000	= 0;	-- Find Jenlyns by the Royal Promenade.
local SEQ_010	= 10;	-- Slay the undead south of the Coffer & Coffin.
local SEQ_020	= 20;	-- Report to Jenlyns.

local ENPC_LULUTSU	= 1000863;
local ENPC_JENLYNS	= 1060042;
local UNDEAD_TRIGGER = 1090938;

local JOB_PALADIN = 16;

local FIGHT = { 172, -1726.0, 56.1, -270.0, 3.1 };

local TALKS = {
	[SEQ_000] = { [ENPC_LULUTSU] = "processEvent055" },
	[SEQ_010] = { [ENPC_LULUTSU] = "processEvent055", [ENPC_JENLYNS] = "processEvent083" },
	[SEQ_020] = { [ENPC_LULUTSU] = "processEvent055" },
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_LULUTSU, QFLAG_TALK);
		return;
	end
	jobQuest.chatterMarkers(quest, TALKS, sequence);
	if (sequence == SEQ_000) then
		quest:SetENpc(ENPC_JENLYNS, QFLAG_TALK);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(UNDEAD_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(ENPC_JENLYNS, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_LULUTSU) then
		-- The Sultansworn will teach outsiders (1 = accepted).
		if (callClientFunction(player, "delegateEvent", player, quest, "processEventLULUTSUStart") == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and npcClassId == ENPC_JENLYNS) then
		-- What a paladin is, and the trial of the undead.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent082");
		quest:StartSequence(SEQ_010);
	elseif (seq == SEQ_020 and npcClassId == ENPC_JENLYNS) then
		-- The disgraced crystal, and the true Soul of the Paladin.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		jobQuest.giveSoulCrystal(player, JOB_PALADIN);
		callClientFunction(player, "delegateEvent", player, quest, "processEventKokuti", jobQuest.SOUL_CRYSTAL[JOB_PALADIN]);
		player:CompleteQuest(quest);
	else
		jobQuest.chatter(player, quest, TALKS, seq, npcClassId);
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc)
	if (quest:GetSequence() == SEQ_010 and npc:GetActorClassId() == UNDEAD_TRIGGER) then
		questBattle.start(player, "Pld0j101", FIGHT, "Quest/SimpleQuestBattle/QuestDirectorWar0j101");
		return;
	end
	player:EndEvent();
end

-- The undead are down; a free paladin hands over a crystal.
jobQuest.registerFight(111281, SEQ_010, function(player, quest)
	callClientFunction(player, "delegateEvent", player, quest, "processEvent015");
	quest:StartSequence(SEQ_020);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end);

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
