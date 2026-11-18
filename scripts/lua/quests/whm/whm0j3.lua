require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	Lost in Rage
Code:	Whm0j3
Id:		111243
Prereq: Whm0j2, White Mage 40

The elementals are growing angry. Raya-O-Senna sends you to calm Cactuar
Jack, a cactuar gone savage east of Camp Horizon in Western Thanalan
(processEventRAYAOSENNAStart). Walking into its ground starts the fight
(SimpleContentWhm0j301). Back at the cave Raya-O grants you new white
magic (processEvent005).

]]

local SEQ_000	= 0;	-- Subdue Cactuar Jack east of Camp Horizon.
local SEQ_005	= 5;	-- Return to Raya-O-Senna.

local ENPC_RAYA_O_SENNA	= 1001570;
local FIGHT_TRIGGER		= 1090922;

local FIGHT = { 172, -825.0, 120.5, -40.0, -1.6 };

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_RAYA_O_SENNA, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ENPC_RAYA_O_SENNA);
		quest:SetENpc(FIGHT_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_005) then
		quest:SetENpc(ENPC_RAYA_O_SENNA, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc, eventName)
	local seq = quest:GetSequence();
	if (npc.GetActorClassId() == ENPC_RAYA_O_SENNA) then
		if (seq == SEQ_ACCEPT) then
			-- 1 = accepted.
			if (callClientFunction(player, "delegateEvent", player, quest, "processEventRAYAOSENNAStart") == 1) then
				player:AcceptQuest(quest);
			end
		elseif (seq == SEQ_000) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000");
		elseif (seq == SEQ_005) then
			-- Oha-Sok's answer, and new white magic.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005");
			player:CompleteQuest(quest);
		end
	end
	player:EndEvent();
end

function onPush(player, quest, npc)
	if (quest:GetSequence() == SEQ_000 and npc:GetActorClassId() == FIGHT_TRIGGER) then
		questBattle.start(player, "Whm0j301", FIGHT, "Quest/SimpleQuestBattle/QuestDirectorWar0j101");
		return;
	end
	player:EndEvent();
end

jobQuest.registerFight(111243, SEQ_000, function(player, quest)
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
