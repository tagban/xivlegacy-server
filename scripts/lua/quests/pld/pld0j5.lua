require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	Parley on High Ground
Code:	Pld0j5
Id:		111285
Prereq: Pld0j4, Paladin 45

Jenlyns has arranged a parley with Solkzagyl on high ground northeast of
Ul'dah to win back Oathkeeper, and asks you to come in case it is a trap
(processEventJENLYNSStart). At the parley Jenlyns turns his blade on you,
sure you are in league with the traitor (processEvent_005NQ_1 cutscene),
and you must fight him and his men (SimpleContentPld0j501). Solkzagyl
arrives: the men were the Monetarists' assassins, and Jenlyns was their
dupe (processEvent_015NQ_2 cutscene). The quest ends there
(processEventClear).

Jenlyns's men are Sultansworn elites (the client's Paladin's Pledge foe).

]]

local SEQ_000 = 0;	-- Go to the parley northeast of Ul'dah.

local ENPC_JENLYNS		= 1060042;
local PARLEY_TRIGGER	= 1090945;

local FIGHT = { 170, 90.0, 199.2, -590.0, 0.0 };

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_JENLYNS, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ENPC_JENLYNS);
		quest:SetENpc(PARLEY_TRIGGER, QFLAG_PUSH, false, true);
	end
end

function onTalk(player, quest, npc, eventName)
	if (npc.GetActorClassId() == ENPC_JENLYNS) then
		if (quest:GetSequence() == SEQ_ACCEPT) then
			-- The parley with Solkzagyl (1 = accepted).
			if (callClientFunction(player, "delegateEvent", player, quest, "processEventJENLYNSStart") == 1) then
				player:AcceptQuest(quest);
			end
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_000_JENLYNSSFollow");
		end
	end
	player:EndEvent();
end

function onPush(player, quest, npc)
	if (quest:GetSequence() == SEQ_000 and npc:GetActorClassId() == PARLEY_TRIGGER) then
		-- Jenlyns turns on you.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_005NQ_1");
		questBattle.start(player, "Pld0j501", FIGHT, "Quest/SimpleQuestBattle/QuestDirectorWar0j101");
		return;
	end
	player:EndEvent();
end

-- Jenlyns is beaten; Solkzagyl tells the truth.
jobQuest.registerFight(111285, SEQ_000, function(player, quest)
	callClientFunction(player, "delegateEvent", player, quest, "processEvent_015NQ_2");
	callClientFunction(player, "delegateEvent", player, quest, "processEventClear");
	player:CompleteQuest(quest);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end);

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
