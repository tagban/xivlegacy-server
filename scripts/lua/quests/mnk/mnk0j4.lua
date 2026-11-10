require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	Good Vibrations
Code:	Mnk0j4
Id:		111224
Prereq: Mnk0j3, Monk 45

Erik is furious that you and Widargelt measured the same place, but the
results point him at a new theory. The proof lies northwest of Camp Horizon
in Western Thanalan, where the aether is in flux and the basilisk Apep
stands in the way (processEventERIKStart). Walking into Apep's ground
starts the fight (SimpleContentMnk0j401). The quest ends there, away from
any NPC (onJobQuestComplete*).

No Apep model is in the client's monster list; a basilisk stands in.

]]

local SEQ_000 = 0;	-- Slay Apep northwest of Camp Horizon.

local ENPC_ERIK			= 1060033;
local ENPC_WIDARGELT	= 1060032;
local APEP_TRIGGER		= 1090914;

local FIGHT = { 172, -1340.0, 56.0, -262.0, -1.6 };

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_ERIK, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ENPC_ERIK);
		quest:SetENpc(ENPC_WIDARGELT);
		quest:SetENpc(APEP_TRIGGER, QFLAG_PUSH, false, true);
	end
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	if (quest:GetSequence() == SEQ_ACCEPT) then
		if (npcClassId == ENPC_ERIK) then
			-- The flux northwest of Camp Horizon, and Apep (1 = accepted).
			if (callClientFunction(player, "delegateEvent", player, quest, "processEventERIKStart") == 1) then
				player:AcceptQuest(quest);
			end
		end
	elseif (npcClassId == ENPC_ERIK) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000");
	elseif (npcClassId == ENPC_WIDARGELT) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_1");
	end
	player:EndEvent();
end

function onPush(player, quest, npc)
	if (quest:GetSequence() == SEQ_000 and npc:GetActorClassId() == APEP_TRIGGER) then
		questBattle.start(player, "Mnk0j401", FIGHT, "Quest/SimpleQuestBattle/QuestDirectorWar0j101");
		return;
	end
	player:EndEvent();
end

-- Apep is down; the measurement is taken.
jobQuest.registerFight(111224, SEQ_000, function(player, quest)
	jobQuest.completeAway(player, quest);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end);

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
