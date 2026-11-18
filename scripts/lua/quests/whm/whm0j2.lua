require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	When Sheep Attack
Code:	Whm0j2
Id:		111242
Prereq: Whm0j1, White Mage 35

Back at the cave, Raya-O-Senna argues with the elemental Oha-Sok, then
asks you to calm Downy Dunstan, a sheep gone wild southwest of Camp Glory
that the elementals seem to drive (processEventRAYAOSENNAStart, cutscene
whm0j210). Walking into its pasture starts the fight
(SimpleContentWhm0j201). Back at the cave Oha-Sok has little to say, and
Raya-O grants you new white magic (processEvent005).

]]

local SEQ_000	= 0;	-- Subdue Downy Dunstan southwest of Camp Glory.
local SEQ_005	= 5;	-- Return to Raya-O-Senna.

local ENPC_RAYA_O_SENNA	= 1001570;
local FIGHT_TRIGGER		= 1090921;

local FIGHT = { 145, 1440.0, 214.1, 820.0, 3.1 };

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
		questBattle.start(player, "Whm0j201", FIGHT, "Quest/SimpleQuestBattle/QuestDirectorWar0j101");
		return;
	end
	player:EndEvent();
end

jobQuest.registerFight(111242, SEQ_000, function(player, quest)
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
