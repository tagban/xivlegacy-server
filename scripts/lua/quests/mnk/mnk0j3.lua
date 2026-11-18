require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	The Pursuit of Power
Code:	Mnk0j3
Id:		111223
Prereq: Mnk0j2, Monk 40

Erik wants two things: Widargelt's aetheriometer, and a measurement at the
Mun-Tuy Cellars in the North Shroud (processEventStart). Widargelt, at
Little Ala Mhigo, says his own measurements are not done
(processEventStartAfter), so you go to the cellars first, where the Prince
of Pestilence stands in the way (SimpleContentMnk0j301). With the Prince
down, find a spot for the measurement (processEventPoint): Widargelt has
been there before you (processEventClear cutscene), and the monk's
training goes on (processEventAfget).

]]

local SEQ_000	= 0;	-- Collect the aetheriometer from Widargelt at Little Ala Mhigo.
local SEQ_010	= 10;	-- Slay the Prince of Pestilence near the Mun-Tuy Cellars.
local SEQ_020	= 20;	-- Take the measurement.

local ENPC_ERIK			= 1060033;
local ENPC_WIDARGELT	= 1060032;
local PRINCE_TRIGGER	= 1090912;
local MEASURE_POINT		= 1090913;

local FIGHT = { 157, -775.0, -14.7, -2345.0, 2.4 };

local TALKS = {
	[SEQ_000] = { [ENPC_ERIK] = "processEventAfterTolk01" },
	[SEQ_010] = { [ENPC_ERIK] = "processEventAfterTolk01", [ENPC_WIDARGELT] = "processEventAfterTolk02" },
	[SEQ_020] = { [ENPC_ERIK] = "processEventAfterTolk01", [ENPC_WIDARGELT] = "processEventWidargeltAfter" },
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_ERIK, QFLAG_TALK);
		return;
	end
	jobQuest.chatterMarkers(quest, TALKS, sequence);
	if (sequence == SEQ_000) then
		quest:SetENpc(ENPC_WIDARGELT, QFLAG_TALK);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(PRINCE_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(MEASURE_POINT, QFLAG_PUSH, false, true);
	end
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_ERIK) then
		-- Two more tasks (1 = accepted).
		if (callClientFunction(player, "delegateEvent", player, quest, "processEventStart") == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and npcClassId == ENPC_WIDARGELT) then
		-- His measurements are not done; go on to the cellars.
		callClientFunction(player, "delegateEvent", player, quest, "processEventStartAfter");
		quest:StartSequence(SEQ_010);
	else
		jobQuest.chatter(player, quest, TALKS, seq, npcClassId);
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc)
	local seq = quest:GetSequence();
	local classId = npc:GetActorClassId();
	if (seq == SEQ_010 and classId == PRINCE_TRIGGER) then
		questBattle.start(player, "Mnk0j301", FIGHT, "Quest/SimpleQuestBattle/QuestDirectorWar0j101");
		return;
	elseif (seq == SEQ_020 and classId == MEASURE_POINT) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventPoint");
		callClientFunction(player, "delegateEvent", player, quest, "processEventClear");
		callClientFunction(player, "delegateEvent", player, quest, "processEventAfget");
		player:CompleteQuest(quest);
	end
	player:EndEvent();
end

-- The Prince is down.
jobQuest.registerFight(111223, SEQ_010, function(player, quest)
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
