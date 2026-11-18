require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	Bard's-Eye View
Code:	Brd0j3
Id:		111303
Prereq: Brd0j2, Bard 40

Common bards owe their craft to archers too: peace left soldiers idle,
and many traded the bow for the harp. Jehantel will sing you the Ballad of
the Vainglorious Fool once you prove ready by defeating the boar Phaia in
the Central Shroud (processEventJEHANTELStart). Walking into its ground
starts the fight (SimpleContentBrd0j301). The quest ends there, away from
any NPC (onJobQuestComplete*).

]]

local SEQ_000 = 0;	-- Defeat Phaia in the Central Shroud.

local ENPC_JEHANTEL	= 1060039;
local FIGHT_TRIGGER		 = 1090949;

local FIGHT = { 150, -159.7, -0.1, -330.1, 1.6 };

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
		questBattle.start(player, "Brd0j301", FIGHT, "Quest/SimpleQuestBattle/QuestDirectorWar0j101");
		return;
	end
	player:EndEvent();
end

-- Phaia is down.
jobQuest.registerFight(111303, SEQ_000, function(player, quest)
	jobQuest.completeAway(player, quest);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end);

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
