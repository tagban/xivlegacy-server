require ("global")
require ("quest")
require ("questbattle")

--[[

Quest Script

Name: 	No Other Dodo Will Do
Code: 	Etc2u5
Id: 	110690
Prereq: Level 15, any class

Hildie, a carpenter at the Quicksand, wants to win her customers back
from an undercutting rival with a new bow, and the bow needs the rugged
leather of a clever dodo. North of Camp Drybone, stepping onto the spot
starts the fight (SimpleContentEtc2u501, the client's SimpleQuestBattle
QuestDirectorEtc2u501) with three clever dodos; beating them yields the
leather (key item 11000219). Hildie takes it and pays a procurer's fee.

Client script etc2u5: processEventHildieStart (offer), processEvent_000
(while you hunt), processEvent_010 (the hand-in). Journal steps 602-604.
ZAM has no page for this quest, so the fee and experience are estimates.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Get clever dodo leather north of Camp Drybone.
SEQ_010	= 10;	-- Deliver the leather to Hildie.

-- Actor Class Ids
ENPC_HILDIE			= 1000787;
DODO_TRIGGER		= 1090601;

-- Key Items
ITEM_DODO_LEATHER	= 11000219;

-- Quest Markers
MRKR_DODOS			= 11069001;
MRKR_HILDIE			= 11069002;

-- Places: the fight, and where a win or a loss sets you down.
FIGHT				= {171, 1220.0, 280.0, -690.0, 0.0};

-- Rewards
REWARD_EXP			= 500;
REWARD_GIL			= 2000;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_HILDIE, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(DODO_TRIGGER, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_HILDIE);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_HILDIE, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc)
	local seq = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (seq == SEQ_ACCEPT and classId == ENPC_HILDIE) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventHildieStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and classId == ENPC_HILDIE) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_000");
	elseif (seq == SEQ_010 and classId == ENPC_HILDIE) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1);
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(ITEM_DODO_LEATHER, 1);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddGil(REWARD_GIL);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onPush(player, quest, npc)
	if (quest:getSequence() == SEQ_000 and npc:GetActorClassId() == DODO_TRIGGER) then
		questBattle.start(player, "Etc2u501", FIGHT);
		return;
	end
	player:EndEvent();
end

-- QuestDirectorEtc2u501, once the dodos are down: the leather.
function winEtc2u5Fight(player, quest)
	player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(ITEM_DODO_LEATHER, 1, 1);
	player:SendGameMessage(GetWorldMaster(), 25246, MESSAGE_TYPE_SYSTEM, ITEM_DODO_LEATHER, 1); -- You obtain <item>.
	quest:StartSequence(SEQ_010);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end

-- SimpleContentEtc2u501, on a loss.
function loseEtc2u5Fight(player, timedOut)
	questBattle.leave(player, FIGHT);
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_000) then
		return MRKR_DODOS;
	elseif (seq == SEQ_010) then
		return MRKR_HILDIE;
	end
end
