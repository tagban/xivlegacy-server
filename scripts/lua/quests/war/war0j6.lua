require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	How to Quit You
Code:	War0j6
Id:		111206
Prereq: War0j5, Warrior 50

A creature "more man than beast" is attacking the Silver Bazaar, and
Curious Gorge means to stop it before the other mercenaries can
(processEventCURIOUS_GORGEStart). At the hamlet the creature is his lost
brother, Broken Mountain, given over to his inner beast; Gorge fells him
and then loses himself to the same rage (processEvent010, cutscene
war0j610). Fighting Gorge down brings him back (SimpleContentWar0j601).
At his cave he asks you to meet him at the Silver Bazaar
(processEventCURIOUS_GORGE010Follow), where he gives you the last piece of
the armor (processEvent020, cutscene war0j620; processEventClear).

]]

local SEQ_000 = 0;	-- Go to the Silver Bazaar with Curious Gorge.
local SEQ_010 = 10;	-- Meet Curious Gorge at the Silver Bazaar.

local ENPC_CURIOUS_GORGE	= 1060028;
local BAZAAR_TRIGGER		= 1090909;

local FIGHTER_S_CUIRASS = 8032703;

local FIGHT = { 172, -1395.0, 56.0, 561.0, 1.6 };

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_CURIOUS_GORGE, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ENPC_CURIOUS_GORGE);
		quest:SetENpc(BAZAAR_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_CURIOUS_GORGE);
		quest:SetENpc(BAZAAR_TRIGGER, QFLAG_PUSH, false, true);
	end
end

function onTalk(player, quest, npc, eventName)
	if (npc.GetActorClassId() == ENPC_CURIOUS_GORGE) then
		local seq = quest:GetSequence();
		if (seq == SEQ_ACCEPT) then
			-- The creature at the Silver Bazaar (1 = accepted).
			if (callClientFunction(player, "delegateEvent", player, quest, "processEventCURIOUS_GORGEStart") == 1) then
				player:AcceptQuest(quest);
			end
		elseif (seq == SEQ_000) then
			callClientFunction(player, "delegateEvent", player, quest, "processEventCURIOUS_GORGEFollow");
		elseif (seq == SEQ_010) then
			-- Meet me at the Silver Bazaar.
			callClientFunction(player, "delegateEvent", player, quest, "processEventCURIOUS_GORGE010Follow");
		end
	end
	player:EndEvent();
end

function onPush(player, quest, npc)
	if (npc:GetActorClassId() == BAZAAR_TRIGGER) then
		local seq = quest:GetSequence();
		if (seq == SEQ_000) then
			-- Broken Mountain, and Gorge's rage.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
			questBattle.start(player, "War0j601", FIGHT, "Quest/SimpleQuestBattle/QuestDirectorWar0j101");
			return;
		elseif (seq == SEQ_010) then
			-- The fifth piece.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
			player:GetItemPackage(INVENTORY_NORMAL):AddItem(FIGHTER_S_CUIRASS, 1, 1);
			callClientFunction(player, "delegateEvent", player, quest, "processEventClear");
			player:CompleteQuest(quest);
		end
	end
	player:EndEvent();
end

-- Curious Gorge is himself again.
jobQuest.registerFight(111206, SEQ_000, function(player, quest)
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
