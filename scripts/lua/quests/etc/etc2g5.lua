require ("global")
require ("quest")
require ("questbattle")

--[[

Quest Script

Name: 	Losing One's Thread
Code: 	Etc2g5
Id: 	110669
Prereq: Level 25, any class

Honga Vunga, a Lalafell weaver at the Adventurers' Guild in Gridania, was
waylaid by goblins on his way home and lost his needle box (key item
11000221). The goblins prowl east of Camp Tranquil; stepping into the
hollow there starts the fight (SimpleContentEtc2g501, the client's
SimpleQuestBattle QuestDirectorEtc2g501). Beating them yields the box.
Honga Vunga takes it back and shares some weaver wisdom. Reward 10 undyed
hempen cloth (the client's reward table, data/01/03/05/61.DAT); the table
gives the experience only as a rank, so that amount is an estimate.

Client script etc2g5: processEventHONGAVUNGAStart (offer), processEvent000
(while you hunt), processEvent010 (the reward). Journal steps 407-409.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Take the needle box back from the goblins east of Camp Tranquil.
SEQ_010	= 10;	-- Return the needle box to Honga Vunga.

-- Actor Class Ids
ENPC_HONGA_VUNGA	= 1000429;
HOLLOW_TRIGGER		= 1090607;

-- Key Items
ITEM_NEEDLE_BOX		= 11000221;

-- Quest Markers
MRKR_HOLLOW			= 11066901;
MRKR_HONGA_VUNGA	= 11066902;

-- Places: the fight, and where a win or a loss sets you down (outside the
-- trigger circle, toward the camp).
FIGHT				= {154, 870.0, -12.12, 1092.0, 1.57};

-- Rewards
REWARD_EXP			= 1500;
REWARD_CLOTH		= 10005001;
REWARD_CLOTH_QTY	= 10;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_HONGA_VUNGA, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(HOLLOW_TRIGGER, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_HONGA_VUNGA);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_HONGA_VUNGA, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc)
	local seq = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (seq == SEQ_ACCEPT and classId == ENPC_HONGA_VUNGA) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventHONGAVUNGAStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and classId == ENPC_HONGA_VUNGA) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000");
	elseif (seq == SEQ_010 and classId == ENPC_HONGA_VUNGA) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1);
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(ITEM_NEEDLE_BOX, 1);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:GetItemPackage(INVENTORY_NORMAL):AddItem(REWARD_CLOTH, REWARD_CLOTH_QTY, 1);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onPush(player, quest, npc)
	if (quest:getSequence() == SEQ_000 and npc:GetActorClassId() == HOLLOW_TRIGGER) then
		questBattle.start(player, "Etc2g501", FIGHT);
		return;
	end
	player:EndEvent();
end

-- QuestDirectorEtc2g501, once every goblin is down: the needle box.
function winEtc2g5Fight(player, quest)
	player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(ITEM_NEEDLE_BOX, 1, 1);
	player:SendGameMessage(GetWorldMaster(), 25246, MESSAGE_TYPE_SYSTEM, ITEM_NEEDLE_BOX, 1);
	attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
	quest:StartSequence(SEQ_010);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end

-- SimpleContentEtc2g501, on a loss.
function loseEtc2g5Fight(player, timedOut)
	questBattle.leave(player, FIGHT);
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_000) then
		return MRKR_HOLLOW;
	elseif (seq == SEQ_010) then
		return MRKR_HONGA_VUNGA;
	end
end
