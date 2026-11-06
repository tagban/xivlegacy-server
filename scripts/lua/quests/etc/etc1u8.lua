require ("global")
require ("quest")
require ("questbattle")

--[[

Quest Script

Name: 	Traumaturgy
Code: 	Etc1u8
Id: 	110683
Prereq: Level 36, any class; Clasping to Hope (Etc1u7)

Theda is safe, but the ordeal has left her raving for her "precious
ring", which her Amalj'aa captors seem to have taken. Prelate Totono sends
you after them: they fled from Halatali to a mesa in the northeast, and
stepping onto the flats below it starts the fight (SimpleContentEtc1u801,
the client's SimpleQuestBattle QuestDirectorEtc1u801). Beating them yields
the ring (key item 11000166). Totono tells you Theda has left the Order:
one Amalj'aa had shown her kindness, and the ring was its gift. Reward 6
hi-potions of piety (the client's reward table, data/01/03/05/61.DAT); the
table gives the experience only as a rank, so that amount is an estimate.

Client script etc1u8: processEventTotonoStart (offer), followEvent005
(Totono while you hunt), processEvent010 (the reward). Journal steps
298-300.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Defeat the Amalj'aa northeast of Halatali and find Theda's ring.
SEQ_010	= 10;	-- Bring the ring to Prelate Totono.

-- Actor Class Ids
ENPC_TOTONO			= 1001143;
MESA_TRIGGER		= 1090612;

-- Key Items
ITEM_RING			= 11000166;

-- Quest Markers
MRKR_MESA			= 11068301;
MRKR_TOTONO			= 11068302;

-- Places: the fight, and where a win or a loss sets you down (outside the
-- trigger circle).
FIGHT				= {171, 1720.0, 257.3, -395.0, 0.0};

-- Rewards
REWARD_EXP			= 2500;
REWARD_POTIONS		= 3020528;
REWARD_POTIONS_QTY	= 6;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_TOTONO, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(MESA_TRIGGER, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_TOTONO);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_TOTONO, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc)
	local seq = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (seq == SEQ_ACCEPT and classId == ENPC_TOTONO) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventTotonoStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and classId == ENPC_TOTONO) then
		callClientFunction(player, "delegateEvent", player, quest, "followEvent005");
	elseif (seq == SEQ_010 and classId == ENPC_TOTONO) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1);
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(ITEM_RING, 1);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:GetItemPackage(INVENTORY_NORMAL):AddItem(REWARD_POTIONS, REWARD_POTIONS_QTY, 1);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onPush(player, quest, npc)
	if (quest:getSequence() == SEQ_000 and npc:GetActorClassId() == MESA_TRIGGER) then
		questBattle.start(player, "Etc1u801", FIGHT);
		return;
	end
	player:EndEvent();
end

-- QuestDirectorEtc1u801, once the Amalj'aa are down: Theda's ring.
function winEtc1u8Fight(player, quest)
	player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(ITEM_RING, 1, 1);
	player:SendGameMessage(GetWorldMaster(), 25246, MESSAGE_TYPE_SYSTEM, ITEM_RING, 1);
	attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
	quest:StartSequence(SEQ_010);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end

-- SimpleContentEtc1u801, on a loss.
function loseEtc1u8Fight(player, timedOut)
	questBattle.leave(player, FIGHT);
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_000) then
		return MRKR_MESA;
	elseif (seq == SEQ_010) then
		return MRKR_TOTONO;
	end
end
