require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	Power Struggles
Code:	Pld0j3
Id:		111283
Prereq: Pld0j2, Paladin 40

The traitor who took Oathkeeper is Solkzagyl, a Sultansworn captain for
thirty years. Winning the sword back will be hard, so Jenlyns teaches you
more and sends you to Lower La Noscea to defeat the giant crab king Old
Six-arms (processEventJENLYNSStart). Walking into its ground starts the
fight (SimpleContentPld0j301). The quest ends there, away from any NPC
(onJobQuestComplete*).

]]

local SEQ_000 = 0;	-- Defeat Old Six-arms in Lower La Noscea.

local ENPC_JENLYNS		= 1060042;
local FIGHT_TRIGGER		= 1090940;

local FIGHT = { 128, 618.3, 43.4, 334.9, 1.6 };

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
		quest:SetENpc(FIGHT_TRIGGER, QFLAG_PUSH, false, true);
	end
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	if (quest:GetSequence() == SEQ_ACCEPT) then
		if (npcClassId == ENPC_JENLYNS) then
			-- The next lesson (1 = accepted).
			if (callClientFunction(player, "delegateEvent", player, quest, "processEventJENLYNSStart") == 1) then
				player:AcceptQuest(quest);
			end
		end
	elseif (npcClassId == ENPC_JENLYNS) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000");
	end
	player:EndEvent();
end

function onPush(player, quest, npc)
	if (quest:GetSequence() == SEQ_000 and npc:GetActorClassId() == FIGHT_TRIGGER) then
		questBattle.start(player, "Pld0j301", FIGHT, "Quest/SimpleQuestBattle/QuestDirectorWar0j101");
		return;
	end
	player:EndEvent();
end

-- Old Six-arms is down.
jobQuest.registerFight(111283, SEQ_000, function(player, quest)
	jobQuest.completeAway(player, quest);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end);

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
