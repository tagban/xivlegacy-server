require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	Fatal Seduction
Code:	Drg0j5
Id:		111325
Prereq: Drg0j4, Dragoon 45

Ser Alberic confesses that he gave up the dragon's power for fear it would
make him a dragon, and warns you never to forget where your strength comes
from. To awaken the dragon within, you must slay the drake Stollenwurm south
of Camp Riversmeet (processEventALBERICStart). Walking into its ground
starts the fight (SimpleContentDrg0j501). The quest ends there, away from
any NPC (onJobQuestComplete*).

A lava drake stands in for Stollenwurm.

]]

local SEQ_000 = 0;	-- Slay Stollenwurm south of Camp Riversmeet.

local ENPC_ALBERIC	= 1060040;
local FIGHT_TRIGGER		  = 1090964;

local FIGHT = { 148, -1790.0, 271.0, -110.0, 0.0 };

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_ALBERIC, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ENPC_ALBERIC);
		quest:SetENpc(FIGHT_TRIGGER, QFLAG_PUSH, false, true);
	end
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	if (quest:GetSequence() == SEQ_ACCEPT) then
		if (npcClassId == ENPC_ALBERIC) then
			-- The next lesson (1 = accepted).
			if (callClientFunction(player, "delegateEvent", player, quest, "processEventALBERICStart") == 1) then
				player:AcceptQuest(quest);
			end
		end
	elseif (npcClassId == ENPC_ALBERIC) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_ALBERICS");
	end
	player:EndEvent();
end

function onPush(player, quest, npc)
	if (quest:GetSequence() == SEQ_000 and npc:GetActorClassId() == FIGHT_TRIGGER) then
		questBattle.start(player, "Drg0j501", FIGHT, "Quest/SimpleQuestBattle/QuestDirectorWar0j101");
		return;
	end
	player:EndEvent();
end

-- Stollenwurm is down.
jobQuest.registerFight(111325, SEQ_000, function(player, quest)
	jobQuest.completeAway(player, quest);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end);

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
