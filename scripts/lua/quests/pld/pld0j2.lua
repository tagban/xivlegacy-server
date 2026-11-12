require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	Honor Lost
Code:	Pld0j2
Id:		111282
Prereq: Pld0j1, Paladin 35

Jenlyns tells you the Sultansworn lost their good name when a traitor
stole the sword Oathkeeper, handed down by their captains. To ready you to
win it back he teaches you more and sends you after the alux that lurks in
the Mun-Tuy Cellars of the North Shroud (processEventJENLYNSStart). Walking
into its lair starts the fight (SimpleContentPld0j201). The quest ends
there, away from any NPC (onJobQuestComplete*).

]]

local SEQ_000 = 0;	-- Defeat the alux in the Mun-Tuy Cellars.

local ENPC_JENLYNS		= 1060042;
local FIGHT_TRIGGER		= 1090939;

local FIGHT = { 157, -747.0, -23.4, -2295.0, 1.6 };

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
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_JENLYNS");
	end
	player:EndEvent();
end

function onPush(player, quest, npc)
	if (quest:GetSequence() == SEQ_000 and npc:GetActorClassId() == FIGHT_TRIGGER) then
		questBattle.start(player, "Pld0j201", FIGHT, "Quest/SimpleQuestBattle/QuestDirectorWar0j101");
		return;
	end
	player:EndEvent();
end

-- The alux is down.
jobQuest.registerFight(111282, SEQ_000, function(player, quest)
	jobQuest.completeAway(player, quest);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end);

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
