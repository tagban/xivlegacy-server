require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	The Archer's Anthem
Code:	Brd0j2
Id:		111302
Prereq: Brd0j1, Bard 35

Jehantel tells how bards were born: archers who sang to bear the strain of
battle. To understand it, face Bardi, a lone jackal prowling the Nanawa
Mines north of Ul'dah (processEventJEHANTELStart). Walking into its ground
starts the fight (SimpleContentBrd0j201). The quest ends there, away from
any NPC (onJobQuestComplete*).

]]

local SEQ_000 = 0;	-- Face Bardi in the Nanawa Mines.

local ENPC_JEHANTEL	= 1060039;
local FIGHT_TRIGGER		 = 1090948;

local FIGHT = { 176, -157.0, 167.0, -1313.0, 2.4 };

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_JEHANTEL, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ENPC_JEHANTEL);
		quest:SetENpc(FIGHT_TRIGGER, QFLAG_PUSH, false, true);
	end
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	if (quest:GetSequence() == SEQ_ACCEPT) then
		if (npcClassId == ENPC_JEHANTEL) then
			-- The next lesson (1 = accepted).
			if (callClientFunction(player, "delegateEvent", player, quest, "processEventJEHANTELStart") == 1) then
				player:AcceptQuest(quest);
			end
		end
	elseif (npcClassId == ENPC_JEHANTEL) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000");
	end
	player:EndEvent();
end

function onPush(player, quest, npc)
	if (quest:GetSequence() == SEQ_000 and npc:GetActorClassId() == FIGHT_TRIGGER) then
		questBattle.start(player, "Brd0j201", FIGHT, "Quest/SimpleQuestBattle/QuestDirectorWar0j101");
		return;
	end
	player:EndEvent();
end

-- Bardi is down.
jobQuest.registerFight(111302, SEQ_000, function(player, quest)
	jobQuest.completeAway(player, quest);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end);

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
