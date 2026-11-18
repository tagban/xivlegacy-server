require ("global")
require ("quest")

--[[

Quest Script

Name:	A Fruitful Murder
Code:	Wvr306
Id:	110402
Prereq: Level 36, Weaver

A maiden fled the royal ball leaving a single glove, the prince is
searching Ul'dah with it, and every lady in town wants a single glove made.
Deaustie wants ten pairs of luxurious gloves. Chuchumu says they need
Thanalan spider silk from the Copperbell Mines; at the mine entrance you
find her stuck in webs, and each strand of silk you peel off her goes into
a pair of gloves (with undyed velveteen and cotton yarn). Hand the ten
pairs to Deaustie just as the prince walks in and finds his love (wvr30610),
watch the next scene at the Gold Court (wvr30620), and Deaustie lets you in
on the Sunsilk Troupe's play (wvr30630): 36,000 gil and 3,600 experience.

The silk comes one strand per talk with Chuchumu at the mine (a strand at a
time, as in the original); the gloves have no recipe on this server yet, so
the ten pairs are checked in the bag as they would come out of synthesis.
Chuchumu has public spawns at Sunsilk (1000905, spawn 31060) and at the
Copperbell Mines entrance (1000906, spawn 31061); the Gold Court scene plays
at a push circle (1091161, spawn 31064).

Journal: steps 174-178, 239 and 240 of the quest journal sheet (0B/45/08/4E).

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Ask Chuchumu about the gloves.
SEQ_008	= 8;   -- Go to the Copperbell Mines for spider silk.
SEQ_009	= 9;   -- Free Chuchumu from the webs and make the gloves.
SEQ_010	= 10;  -- Deliver the ten pairs to Deaustie.
SEQ_020	= 20;  -- See how it ends at the Gold Court.
SEQ_030	= 30;  -- Back to Deaustie for the reward.

-- Actor Class Ids
ENPC_DEAUSTIE		= 1000293;
ENPC_LOHWAEB		= 1000644;
ENPC_MARGARETE		= 1000645;
ENPC_RINH_MAIMHOV	= 1000646;
ENPC_CAHERNAUT		= 1000915;
ENPC_ASPIPI			= 1000916;
ENPC_GLOIUCEN		= 1000917;
ENPC_CHUCHUMU		= 1000905; -- Sunsilk Tapestries
ENPC_CHUCHUMU_MINES	= 1000906; -- Copperbell Mines entrance
ENPC_GOLD_COURT		= 1091161; -- push circle at the Gold Court

ITEM_GLOVES		= 11000056; -- luxurious gloves (crafted)
ITEM_SPIDER_SILK	= 11000057; -- Thanalan spider silk (a synthesis input)
GLOVES_NEEDED	= 10;

REWARD_GIL	= 36000;
REWARD_EXP	= 3600;

-- Markers (01/03/05/A9: one per cutscene).
MRKR_SUNSILK	= 11040201; -- wvr30610
MRKR_GOLD_COURT	= 11040202; -- wvr30620
MRKR_DEAUSTIE	= 11040203; -- wvr30630

-- The weavers' chatter; slot 2 is Deaustie, the other slots go to the same
-- weavers as in Wvr200 and Wvr300.
WEAVERS_005 = {
	[ENPC_DEAUSTIE] = "processEvent005_2",
	[ENPC_LOHWAEB] = "processEvent005_3",
	[ENPC_MARGARETE] = "processEvent005_4",
	[ENPC_RINH_MAIMHOV] = "processEvent005_5",
	[ENPC_CAHERNAUT] = "processEvent005_6",
	[ENPC_ASPIPI] = "processEvent005_7",
	[ENPC_GLOIUCEN] = "processEvent005_8",
};

TALKS = {
	[SEQ_000] = WEAVERS_005,
	[SEQ_008] = WEAVERS_005,
	[SEQ_009] = WEAVERS_005,
	[SEQ_010] = {
		[ENPC_LOHWAEB] = "processEvent005_3",
		[ENPC_MARGARETE] = "processEvent005_4",
		[ENPC_RINH_MAIMHOV] = "processEvent005_5",
		[ENPC_CAHERNAUT] = "processEvent005_6",
		[ENPC_ASPIPI] = "processEvent005_7",
		[ENPC_GLOIUCEN] = "processEvent005_8",
	},
	[SEQ_020] = {
		[ENPC_DEAUSTIE] = "processEvent010_2",
		[ENPC_LOHWAEB] = "processEvent010_3",
		[ENPC_MARGARETE] = "processEvent010_4",
		[ENPC_RINH_MAIMHOV] = "processEvent010_5",
		[ENPC_CAHERNAUT] = "processEvent010_6",
		[ENPC_ASPIPI] = "processEvent010_7",
		[ENPC_GLOIUCEN] = "processEvent010_8",
	},
	[SEQ_030] = {
		[ENPC_LOHWAEB] = "processEvent020_2",
	},
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_DEAUSTIE, QFLAG_TALK);
		return;
	end
	if (TALKS[sequence] ~= nil) then
		for classId, _ in pairs(TALKS[sequence]) do
			quest:SetENpc(classId);
		end
	end
	if (sequence == SEQ_000) then
		quest:SetENpc(ENPC_CHUCHUMU, QFLAG_TALK);
	elseif (sequence == SEQ_008) then
		quest:SetENpc(ENPC_CHUCHUMU);
		quest:SetENpc(ENPC_CHUCHUMU_MINES, QFLAG_TALK);
	elseif (sequence == SEQ_009) then
		quest:SetENpc(ENPC_CHUCHUMU_MINES, QFLAG_TALK);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_DEAUSTIE, QFLAG_TALK);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(ENPC_GOLD_COURT, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_030) then
		quest:SetENpc(ENPC_DEAUSTIE, QFLAG_REWARD);
	end
end

local function itemCount(player, itemId)
	return player:GetItemPackage(INVENTORY_NORMAL):GetItemQuantity(itemId);
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_DEAUSTIE) then
		-- The prince's glove and the rush of orders (1 = accepted).
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventDeaustieStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and npcClassId == ENPC_CHUCHUMU) then
		-- The gloves need spider silk from the Copperbell Mines.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent008");
		quest:StartSequence(SEQ_008);
	elseif (seq == SEQ_008 and npcClassId == ENPC_CHUCHUMU) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent008_2");
	elseif (seq == SEQ_008 and npcClassId == ENPC_CHUCHUMU_MINES) then
		-- Chuchumu, chased by a spider and stuck in its webs.
		callClientFunction(player, "delegateEvent", player, quest, "processEventS002_1");
		quest:StartSequence(SEQ_009);
	elseif (seq == SEQ_009 and npcClassId == ENPC_CHUCHUMU_MINES) then
		if (itemCount(player, ITEM_GLOVES) >= GLOVES_NEEDED) then
			-- All ten pairs made: she heads back to Sunsilk ahead of you.
			callClientFunction(player, "delegateEvent", player, quest, "processEventS004_1");
			quest:StartSequence(SEQ_010);
		elseif (itemCount(player, ITEM_SPIDER_SILK) > 0) then
			-- Use the strand you have first.
			callClientFunction(player, "delegateEvent", player, quest, "processEventS003_1");
		else
			-- Peel off another strand of silk.
			callClientFunction(player, "delegateEvent", player, quest, "processEventS001_1");
			player:GetItemPackage(INVENTORY_NORMAL):AddItem(ITEM_SPIDER_SILK, 1, 1);
		end
	elseif (seq == SEQ_010 and npcClassId == ENPC_DEAUSTIE) then
		if (itemCount(player, ITEM_GLOVES) >= GLOVES_NEEDED) then
			-- wvr30610: the gloves, the prince and his love.
			player:GetItemPackage(INVENTORY_NORMAL):RemoveItem(ITEM_GLOVES, GLOVES_NEEDED);
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
			quest:StartSequence(SEQ_020);
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005_2");
		end
	elseif (seq == SEQ_030 and npcClassId == ENPC_DEAUSTIE) then
		-- wvr30630: the Sunsilk Troupe's secret, and payment.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 2);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddGil(REWARD_GIL);
		player:CompleteQuest(quest);
	elseif (TALKS[seq] ~= nil and TALKS[seq][npcClassId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, TALKS[seq][npcClassId]);
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (npcClassId == ENPC_GOLD_COURT and seq == SEQ_020) then
		-- wvr30620: Chuchumu on the dowry, and the Echo's poisoned apples.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		quest:StartSequence(SEQ_030);
	end
	player:EndEvent();
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:GetSequence();
	if (seq == SEQ_010) then
		return MRKR_SUNSILK;
	elseif (seq == SEQ_020) then
		return MRKR_GOLD_COURT;
	elseif (seq == SEQ_030) then
		return MRKR_DEAUSTIE;
	end
end
