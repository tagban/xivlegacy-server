require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	Keeping the Oath
Code:	Pld0j6
Id:		111286
Prereq: Pld0j5, Paladin 50

Jenlyns knows now that the Monetarists used him. His captaincy may be a
sham, but he will strike back, southeast of Camp Bluefog, and tells you to
keep away (processEventStart). There you find him and Solkzagyl facing the
Monetarists' monsters (processEventNQ01 cutscene); help them
(SimpleContentPld0j601). Solkzagyl leaves the Sultansworn to Jenlyns and
goes his way (processEventNQ02 cutscene). Back by the Royal Promenade,
Jenlyns gives you the Gallant Surcoat (processEventClear,
processEventKokuti).

The Monetarists' monsters aren't named in the client; Sultansworn elites
stand in for the hired blades.

]]

local SEQ_000	= 0;	-- Go to the battle southeast of Camp Bluefog.
local SEQ_010	= 10;	-- Speak to Jenlyns by the Royal Promenade.

local ENPC_JENLYNS		= 1060042;
local BATTLE_TRIGGER	= 1090946;

local GALLANT_SURCOAT = 8032701;

local FIGHT = { 173, -80.0, 280.3, -1605.0, -1.6 };

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
		quest:SetENpc(BATTLE_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_JENLYNS, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc, eventName)
	local seq = quest:GetSequence();
	if (npc.GetActorClassId() == ENPC_JENLYNS) then
		if (seq == SEQ_ACCEPT) then
			-- The showdown with the Monetarists (1 = accepted).
			if (callClientFunction(player, "delegateEvent", player, quest, "processEventStart") == 1) then
				player:AcceptQuest(quest);
			end
		elseif (seq == SEQ_000) then
			callClientFunction(player, "delegateEvent", player, quest, "processEventStartAfter");
		elseif (seq == SEQ_010) then
			callClientFunction(player, "delegateEvent", player, quest, "processEventClear");
			player:GetItemPackage(INVENTORY_NORMAL):AddItem(GALLANT_SURCOAT, 1, 1);
			callClientFunction(player, "delegateEvent", player, quest, "processEventKokuti", GALLANT_SURCOAT);
			player:CompleteQuest(quest);
		end
	end
	player:EndEvent();
end

function onPush(player, quest, npc)
	if (quest:GetSequence() == SEQ_000 and npc:GetActorClassId() == BATTLE_TRIGGER) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventNQ01");
		questBattle.start(player, "Pld0j601", FIGHT, "Quest/SimpleQuestBattle/QuestDirectorWar0j101");
		return;
	end
	player:EndEvent();
end

-- The Monetarists' cohort is down; Solkzagyl goes his way.
jobQuest.registerFight(111286, SEQ_000, function(player, quest)
	callClientFunction(player, "delegateEvent", player, quest, "processEventNQ02");
	quest:StartSequence(SEQ_010);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end);

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
