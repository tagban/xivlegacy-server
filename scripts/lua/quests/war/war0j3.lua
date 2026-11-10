require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	Curious Gorge Goes to the Bazaar
Code:	War0j3
Id:		111203
Prereq: War0j2, Warrior 40

The chronicles say the city-states blamed the warriors' art for soldiers
lost to their rage. To win the art back its good name, Curious Gorge
takes a Company of Heroes job: canyon condors hunt the children of the
Silver Bazaar, and he will come at them from the west while you come
from the north, then the east (processEventCURIOUSGORGEStart). Walking
into the condors' ground north of the hamlet starts the fight
(SimpleContentWar0j301). At the east gate you find the hamlet turning on
Gorge, who flees (processEvent005, cutscene war0j310). Back at his cave
he apologizes, and the quest ends (processEvent010, processEventKokuti).

]]

local SEQ_000 = 0;	-- Slay the condors north of the Silver Bazaar.
local SEQ_005 = 5;	-- Go to the hamlet's east gate.
local SEQ_010 = 10;	-- Visit Curious Gorge.

local ENPC_CURIOUS_GORGE	= 1060028;
local CONDOR_TRIGGER		= 1090902;
local EAST_GATE_TRIGGER		= 1090903;

local FIGHT = { 172, -1340.0, 56.0, 452.0, 3.1 };

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
		quest:SetENpc(CONDOR_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_005) then
		quest:SetENpc(EAST_GATE_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_CURIOUS_GORGE, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (npcClassId == ENPC_CURIOUS_GORGE) then
		if (seq == SEQ_ACCEPT) then
			-- The tribe's disgrace, and the condors (1 = accepted).
			if (callClientFunction(player, "delegateEvent", player, quest, "processEventCURIOUSGORGEStart") == 1) then
				player:AcceptQuest(quest);
			end
		elseif (seq == SEQ_000) then
			-- The two-pronged attack.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000_2");
		elseif (seq == SEQ_010) then
			-- His apology, and the whispers in the soul crystal.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
			callClientFunction(player, "delegateEvent", player, quest, "processEventKokuti");
			player:CompleteQuest(quest);
		end
	end
	player:EndEvent();
end

function onPush(player, quest, npc)
	local npcClassId = npc:GetActorClassId();
	local seq = quest:GetSequence();
	if (seq == SEQ_000 and npcClassId == CONDOR_TRIGGER) then
		questBattle.start(player, "War0j301", FIGHT);
		return;
	elseif (seq == SEQ_005 and npcClassId == EAST_GATE_TRIGGER) then
		-- "You monster!": the hamlet turns on Curious Gorge.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent005");
		quest:StartSequence(SEQ_010);
	end
	player:EndEvent();
end

-- The condors north of the hamlet are down.
jobQuest.registerFight(111203, SEQ_000, function(player, quest)
	attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
	quest:StartSequence(SEQ_005);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end);

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
