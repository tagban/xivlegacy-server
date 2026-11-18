require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	Seeds of Initiative
Code:	Whm0j1
Id:		111241
Prereq: Conjurer 30, a second class at 15 (Job 1: the white mage)

Soileine of Stillglade Fane tells you thieves are taking the broken things
left at Lifemend Stump, and that Seedseer Raya-O-Senna went after them
herself; she is in a cave under a lake west of Camp Emerald Moss
(processEventStart). Raya-O asks you to take back the enchanted staff from
the vilekin in the Mun-Tuy Cellars (processEventRayao). Walking into their
den starts the fight (SimpleContentWhm0j101). Back at the cave she gives
you the Soul of the White Mage (processEventClear, processEventClearNQ
cutscene, processEventJob, processEventKokuti).

The cave's place isn't recorded; Raya-O stands on the lakeshore west of
Emerald Moss. The moogles' asides (processEventMoogle*) need moogle
spawns and are left out.

]]

local SEQ_000	= 0;	-- Find Raya-O-Senna in the cave west of Camp Emerald Moss.
local SEQ_010	= 10;	-- Slay the vilekin in the Mun-Tuy Cellars.
local SEQ_020	= 20;	-- Bring the staff back to Raya-O-Senna.

local ENPC_SOILEINE		= 1000234;
local ENPC_RAYA_O_SENNA	= 1001570;
local DEN_TRIGGER		= 1090920;

local JOB_WHITE_MAGE = 27;

local FIGHT = { 157, -833.0, -23.8, -2321.0, -1.6 };

local TALKS = {
	[SEQ_000] = { [ENPC_SOILEINE] = "processEventStartAfter" },
	[SEQ_010] = { [ENPC_SOILEINE] = "processEventStartAfter", [ENPC_RAYA_O_SENNA] = "processEventRyaoAfter" },
	[SEQ_020] = { [ENPC_SOILEINE] = "processEventStartAfter" },
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_SOILEINE, QFLAG_TALK);
		return;
	end
	jobQuest.chatterMarkers(quest, TALKS, sequence);
	if (sequence == SEQ_000) then
		quest:SetENpc(ENPC_RAYA_O_SENNA, QFLAG_TALK);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(DEN_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(ENPC_RAYA_O_SENNA, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_SOILEINE) then
		-- The thefts, and the Seedseer gone into the wood (1 = accepted).
		if (callClientFunction(player, "delegateEvent", player, quest, "processEventStart") == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and npcClassId == ENPC_RAYA_O_SENNA) then
		-- The stolen staff and the vilekin.
		callClientFunction(player, "delegateEvent", player, quest, "processEventRayao");
		quest:StartSequence(SEQ_010);
	elseif (seq == SEQ_020 and npcClassId == ENPC_RAYA_O_SENNA) then
		-- The Soul of the White Mage.
		callClientFunction(player, "delegateEvent", player, quest, "processEventClear");
		callClientFunction(player, "delegateEvent", player, quest, "processEventClearNQ");
		jobQuest.giveSoulCrystal(player, JOB_WHITE_MAGE);
		callClientFunction(player, "delegateEvent", player, quest, "processEventJob", jobQuest.SOUL_CRYSTAL[JOB_WHITE_MAGE]);
		callClientFunction(player, "delegateEvent", player, quest, "processEventKokuti");
		player:CompleteQuest(quest);
	else
		jobQuest.chatter(player, quest, TALKS, seq, npcClassId);
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc)
	if (quest:GetSequence() == SEQ_010 and npc:GetActorClassId() == DEN_TRIGGER) then
		questBattle.start(player, "Whm0j101", FIGHT, "Quest/SimpleQuestBattle/QuestDirectorWar0j101");
		return;
	end
	player:EndEvent();
end

-- The vilekin are down and the staff is back.
jobQuest.registerFight(111241, SEQ_010, function(player, quest)
	attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
	quest:StartSequence(SEQ_020);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end);

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
