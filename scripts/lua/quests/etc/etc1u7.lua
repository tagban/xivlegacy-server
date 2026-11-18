require ("global")
require ("quest")
require ("questbattle")

--[[

Quest Script

Name: 	Clasping to Hope
Code: 	Etc1u7
Id: 	110682
Prereq: Level 34, any class

Prelate Totono of Arrzaneth Ossuary tells you an Amalj'aa warband fell on
a convoy of the Order and carried off the novice thaumaturge Theda. The
warband is often seen near Halatali in Eastern Thanalan; stepping onto the
flats west of Halatali starts the fight (SimpleContentEtc1u701, the
client's SimpleQuestBattle QuestDirectorEtc1u701). Beating them yields
Theda's clasp (key item 11000165), which carries her message. Bring it to
Totono. Reward 6 hi-potions of vitality (the client's reward table,
data/01/03/05/61.DAT); the table gives the experience only as a rank, so
that amount is an estimate.

Client script etc1u7: processEventTotonoStart (offer), followEvent005
(Totono while you hunt), processEvent010 (the reward). Journal steps
295-297.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Defeat the Amalj'aa near Halatali and find Theda's clasp.
SEQ_010	= 10;	-- Bring the clasp to Prelate Totono.

-- Actor Class Ids
ENPC_TOTONO			= 1001143;
FLATS_TRIGGER		= 1090611;

-- Key Items
ITEM_CLASP			= 11000165;

-- Quest Markers
MRKR_FLATS			= 11068201;
MRKR_TOTONO			= 11068202;

-- Places: the fight, and where a win or a loss sets you down (outside the
-- trigger circle).
FIGHT				= {171, 1540.0, 255.82, -290.0, 0.0};

-- Rewards
REWARD_EXP			= 2500;
REWARD_POTIONS		= 3020516;
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
		quest:SetENpc(FLATS_TRIGGER, QFLAG_PUSH, false, true);
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
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(ITEM_CLASP, 1);
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
	if (quest:getSequence() == SEQ_000 and npc:GetActorClassId() == FLATS_TRIGGER) then
		questBattle.start(player, "Etc1u701", FIGHT);
		return;
	end
	player:EndEvent();
end

-- QuestDirectorEtc1u701, once the warband is down: Theda's clasp.
function winEtc1u7Fight(player, quest)
	player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(ITEM_CLASP, 1, 1);
	player:SendGameMessage(GetWorldMaster(), 25246, MESSAGE_TYPE_SYSTEM, ITEM_CLASP, 1);
	attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
	quest:StartSequence(SEQ_010);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end

-- SimpleContentEtc1u701, on a loss.
function loseEtc1u7Fight(player, timedOut)
	questBattle.leave(player, FIGHT);
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_000) then
		return MRKR_FLATS;
	elseif (seq == SEQ_010) then
		return MRKR_TOTONO;
	end
end
