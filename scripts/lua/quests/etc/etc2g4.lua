require ("global")
require ("quest")
require ("questbattle")

--[[

Quest Script

Name: 	To Deskunk A Beer
Code: 	Etc2g4
Id: 	110668
Prereq: Level 31, any class

Lefwyne, an aspiring trader outside the Ebony Stalls, wants to know what
the Knights of Ishgard think of the Mun-Tuy brew the merchant Fafajon
sent them. At Owl's Nest in Coerthas a knight praises its vigor and curses
its stink. Lefwyne knows the cure: sourleaf nectar. Stepping into the
glade east of Humblehearth starts the fight (SimpleContentEtc2g401, the
client's SimpleQuestBattle QuestDirectorEtc2g401) with sourleaf roselets;
their remains yield the nectar (key item 11000202). Bring it to Lefwyne.
Reward 14,000 gil (the client's reward table, data/01/03/05/61.DAT); the
table gives the experience only as a rank, so that amount is an estimate.

The client's scripts don't say which knight answers you; the courtly
knight (class 1000571, no spawn of its own) stands at Owl's Nest beside
Ser Yuhelmeric (open world, visible to everyone).

Client script etc2g4: processEventLefwyneStart (offer), processEvent_000
(Lefwyne while you go), processEvent_010 (the knight at Owl's Nest),
processEvent_010_1 (the knight after), processEvent_020 (Lefwyne: the
nectar), processEvent_020_1 (Lefwyne while you hunt), processEvent_030
(the reward). Journal steps 282-286.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Ask the Knights of Ishgard at Owl's Nest about the brew.
SEQ_010	= 10;	-- Report back to Lefwyne.
SEQ_015	= 15;	-- Get sourleaf nectar from the roselets near Humblehearth.
SEQ_020	= 20;	-- Bring the nectar to Lefwyne.

-- Actor Class Ids
ENPC_LEFWYNE		= 1001396;
ENPC_KNIGHT			= 1000571;
GLADE_TRIGGER		= 1090613;

-- Key Items
ITEM_NECTAR			= 11000202;

-- Quest Markers
MRKR_KNIGHT			= 11066801;
MRKR_LEFWYNE		= 11066802;
MRKR_GLADE			= 11066803;

-- Places: the fight, and where a win or a loss sets you down (outside the
-- trigger circle, toward Humblehearth).
FIGHT				= {150, -66.0, 7.8, -520.0, 1.57};

-- Rewards
REWARD_EXP			= 2000;
REWARD_GIL			= 14000;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_LEFWYNE, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ENPC_KNIGHT, QFLAG_TALK);
		quest:SetENpc(ENPC_LEFWYNE);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_KNIGHT);
		quest:SetENpc(ENPC_LEFWYNE, QFLAG_TALK);
	elseif (sequence == SEQ_015) then
		quest:SetENpc(GLADE_TRIGGER, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_LEFWYNE);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(ENPC_LEFWYNE, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc)
	local seq = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (seq == SEQ_ACCEPT and classId == ENPC_LEFWYNE) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventLefwyneStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (classId == ENPC_LEFWYNE and seq == SEQ_000) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_000");
	elseif (classId == ENPC_KNIGHT and seq == SEQ_000) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010");
		attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
		player:EndEvent();
		quest:StartSequence(SEQ_010);
		return;
	elseif (classId == ENPC_KNIGHT and seq ~= SEQ_ACCEPT) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010_1");
	elseif (classId == ENPC_LEFWYNE and seq == SEQ_010) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_020");
		player:EndEvent();
		quest:StartSequence(SEQ_015);
		return;
	elseif (classId == ENPC_LEFWYNE and seq == SEQ_015) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_020_1");
	elseif (classId == ENPC_LEFWYNE and seq == SEQ_020) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_030");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1);
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(ITEM_NECTAR, 1);
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
	if (quest:getSequence() == SEQ_015 and npc:GetActorClassId() == GLADE_TRIGGER) then
		questBattle.start(player, "Etc2g401", FIGHT);
		return;
	end
	player:EndEvent();
end

-- QuestDirectorEtc2g401, once the roselets are down: the nectar.
function winEtc2g4Fight(player, quest)
	player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(ITEM_NECTAR, 1, 1);
	player:SendGameMessage(GetWorldMaster(), 25246, MESSAGE_TYPE_SYSTEM, ITEM_NECTAR, 1); -- You obtain <item>.
	attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
	quest:StartSequence(SEQ_020);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end

-- SimpleContentEtc2g401, on a loss.
function loseEtc2g4Fight(player, timedOut)
	questBattle.leave(player, FIGHT);
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_000) then
		return MRKR_KNIGHT;
	elseif (seq == SEQ_010 or seq == SEQ_020) then
		return MRKR_LEFWYNE;
	elseif (seq == SEQ_015) then
		return MRKR_GLADE;
	end
end
