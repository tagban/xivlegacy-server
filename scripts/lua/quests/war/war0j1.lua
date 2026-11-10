require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	Pride and Duty (Will Take You from the Mountain)
Code:	War0j1
Id:		111201
Prereq: Marauder 30, Gladiator 15 (Job 1: the warrior)

Neale of the Astalicia has heard of a Hellsguard warrior, newly of the
Company of Heroes, who keeps to a cave southeast of Camp Horizon in
Western Thanalan (processEventStart). There Curious Gorge offers to teach
you the warrior's art once you prove yourself on the antlings that nest
north of his cave (processEventCurious). Walking into the nest starts the
fight (SimpleContentWar0j101). Back at the cave he hands you the Soul of the
Warrior (processEventClear, processEventJob).

Curious Gorge (1060028) had no class script and no spawn; he stands in the
ravine below the plateau. The client script has no point markers for this
quest. Journal steps 328-332 of the guild journal sheet.

]]

-- Sequence Numbers (locals: jobquest_fights.lua loads every job quest
-- script into one Lua state)
local SEQ_000	= 0;	-- Find Curious Gorge's cave southeast of Camp Horizon.
local SEQ_010	= 10;	-- Slay the antlings nesting north of the cave.
local SEQ_020	= 20;	-- Tell Curious Gorge of your victory.

-- Actor Class Ids
local ENPC_NEALE			= 1000090;
local ENPC_CURIOUS_GORGE	= 1060028;
local NEST_TRIGGER		= 1090900;

local JOB_WARRIOR = 17;

-- Where the antling fight is fought (Western Thanalan, on the plateau
-- north of the ravine), outside the nest's circle.
local FIGHT = { 172, -1262.0, 55.7, -132.0, 0.6 };

local TALKS = {
	[SEQ_000] = { [ENPC_NEALE] = "processEventStartAfter" },
	[SEQ_010] = {
		[ENPC_NEALE] = "processEventStartAfter",
		[ENPC_CURIOUS_GORGE] = "processEventCuriousAfter",
	},
	[SEQ_020] = { [ENPC_NEALE] = "processEventStartAfter" },
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_NEALE, QFLAG_TALK);
		return;
	end
	jobQuest.chatterMarkers(quest, TALKS, sequence);
	if (sequence == SEQ_000) then
		quest:SetENpc(ENPC_CURIOUS_GORGE, QFLAG_TALK);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(NEST_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(ENPC_CURIOUS_GORGE, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_NEALE) then
		-- The Hellsguard of the Company of Heroes (1 = accepted).
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and npcClassId == ENPC_CURIOUS_GORGE) then
		-- One remark about the name... and the trial at the antling nest.
		callClientFunction(player, "delegateEvent", player, quest, "processEventCurious");
		quest:StartSequence(SEQ_010);
	elseif (seq == SEQ_020 and npcClassId == ENPC_CURIOUS_GORGE) then
		-- The Soul of the Warrior.
		callClientFunction(player, "delegateEvent", player, quest, "processEventClear");
		jobQuest.giveSoulCrystal(player, JOB_WARRIOR);
		callClientFunction(player, "delegateEvent", player, quest, "processEventJob", jobQuest.SOUL_CRYSTAL[JOB_WARRIOR]);
		player:CompleteQuest(quest);
	else
		jobQuest.chatter(player, quest, TALKS, seq, npcClassId);
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc)
	if (quest:GetSequence() == SEQ_010 and npc:GetActorClassId() == NEST_TRIGGER) then
		questBattle.start(player, "War0j101", FIGHT);
		return;
	end
	player:EndEvent();
end

-- Once the antlings are down (jobQuest.runFightDirector).
jobQuest.registerFight(111201, SEQ_010, function(player, quest)
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
