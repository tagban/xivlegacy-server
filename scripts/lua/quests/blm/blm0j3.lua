require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	International Relations
Code:	Blm0j3
Id:		111263
Prereq: Blm0j2, Black Mage 40

Lalai's next prophecy: three souls of three races have come to Thanalan,
keepers of what is left of the black mages; in a cave west of Camp Horizon
that no map records, Kazagg Chah waits (processEventLALAIStart). There the
Amalj'aa, the Ixal Dozol Meloc and the kobold Da Za tell you of their
shared legend, and Kazagg sets your trial: slay Whitetalon south of Camp
Bald Knoll in Western La Noscea (processEvent005). Walking into her ground
starts the fight (SimpleContentBlm0j301). Back at the cave Kazagg Chah
hears of it (processEvent010, processEventClear).

]]

local SEQ_000	= 0;	-- Find Kazagg Chah in the cave west of Camp Horizon.
local SEQ_005	= 5;	-- Slay Whitetalon south of Camp Bald Knoll.
local SEQ_010	= 10;	-- Return to Kazagg Chah.

local ENPC_LALAI		= 1060034;
local ENPC_KAZAGG_CHAH	= 1060036;
local ENPC_DOZOL_MELOC	= 1060037;
local ENPC_DA_ZA		= 1060038;
local WHITETALON_TRIGGER = 1090931;

local FIGHT = { 129, -1005.0, 51.8, -1000.0, 3.1 };

local TALKS = {
	[SEQ_000] = { [ENPC_LALAI] = "processEvent000", [ENPC_DOZOL_MELOC] = "processEvent000_1", [ENPC_DA_ZA] = "processEvent000_2" },
	[SEQ_005] = { [ENPC_KAZAGG_CHAH] = "processEvent005_1", [ENPC_DOZOL_MELOC] = "processEvent005_2", [ENPC_DA_ZA] = "processEvent005_3" },
	[SEQ_010] = { [ENPC_DOZOL_MELOC] = "processEvent010_1", [ENPC_DA_ZA] = "processEvent010_2" },
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_LALAI, QFLAG_TALK);
		return;
	end
	jobQuest.chatterMarkers(quest, TALKS, sequence);
	if (sequence == SEQ_000) then
		quest:SetENpc(ENPC_KAZAGG_CHAH, QFLAG_TALK);
	elseif (sequence == SEQ_005) then
		quest:SetENpc(WHITETALON_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_KAZAGG_CHAH, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_LALAI) then
		-- Three souls of three races (1 = accepted).
		if (callClientFunction(player, "delegateEvent", player, quest, "processEventLALAIStart") == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and npcClassId == ENPC_KAZAGG_CHAH) then
		-- The three keepers, and the trial of Whitetalon.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent005");
		quest:StartSequence(SEQ_005);
	elseif (seq == SEQ_010 and npcClassId == ENPC_KAZAGG_CHAH) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		callClientFunction(player, "delegateEvent", player, quest, "processEventClear");
		player:CompleteQuest(quest);
	else
		jobQuest.chatter(player, quest, TALKS, seq, npcClassId);
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc)
	if (quest:GetSequence() == SEQ_005 and npc:GetActorClassId() == WHITETALON_TRIGGER) then
		questBattle.start(player, "Blm0j301", FIGHT, "Quest/SimpleQuestBattle/QuestDirectorWar0j101");
		return;
	end
	player:EndEvent();
end

-- Whitetalon is down.
jobQuest.registerFight(111263, SEQ_005, function(player, quest)
	attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
	quest:StartSequence(SEQ_010);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end);

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
