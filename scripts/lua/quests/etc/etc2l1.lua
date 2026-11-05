require ("global")
require ("quest")
require ("questbattle")

--[[

Quest Script

Name: 	Moonstruck
Code: 	Etc2l1
Id: 	110644
Prereq: Level 20, any class

The winemaker I'nairoh of Wineport wants a clear look at Dalamud from the
plains of Bloodshore before the harvest, but frenzied beasts hold the
road. Walk east toward Bloodshore: stepping onto the spot starts the fight
(SimpleContentEtc2l101, the client's SimpleQuestBattle
QuestDirectorEtc2l101) with two aldgoat nannies, a moraby mole and a
black bat. Back at Wineport she tells you what she saw. Reward 12
pineapple juice and 1,280 experience (ZAM).

I'nairoh had no spawn or class script; she stands in Wineport by Walcher.

Client script etc2l1: processEventI_NairohStart (offer), followEvent005
(while the beasts roam), processEvent010 (the reward). Journal steps
175-177.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Clear the road from Wineport to Bloodshore.
SEQ_010	= 10;	-- Return to I'nairoh in Wineport.

-- Actor Class Ids
ENPC_INAIROH		= 1001307;
ROAD_TRIGGER		= 1090605;

-- Quest Markers
MRKR_ROAD			= 11064401;
MRKR_INAIROH		= 11064402;

-- Places: the fight, and where a win or a loss sets you down (outside the
-- trigger circle).
FIGHT				= {130, 820.0, 55.15, -1080.0, 0.0};

-- Rewards
REWARD_EXP			= 1280;
REWARD_JUICE		= 3010606;
REWARD_JUICE_QTY	= 12;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_INAIROH, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ROAD_TRIGGER, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_INAIROH);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_INAIROH, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc)
	local seq = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (seq == SEQ_ACCEPT and classId == ENPC_INAIROH) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventI_NairohStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and classId == ENPC_INAIROH) then
		callClientFunction(player, "delegateEvent", player, quest, "followEvent005");
	elseif (seq == SEQ_010 and classId == ENPC_INAIROH) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:GetItemPackage(INVENTORY_NORMAL):AddItem(REWARD_JUICE, REWARD_JUICE_QTY, 1);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onPush(player, quest, npc)
	if (quest:getSequence() == SEQ_000 and npc:GetActorClassId() == ROAD_TRIGGER) then
		questBattle.start(player, "Etc2l101", FIGHT);
		return;
	end
	player:EndEvent();
end

-- QuestDirectorEtc2l101, once every beast is down.
function winEtc2l1Fight(player, quest)
	attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
	quest:StartSequence(SEQ_010);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end

-- SimpleContentEtc2l101, on a loss.
function loseEtc2l1Fight(player, timedOut)
	questBattle.leave(player, FIGHT);
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_000) then
		return MRKR_ROAD;
	elseif (seq == SEQ_010) then
		return MRKR_INAIROH;
	end
end
