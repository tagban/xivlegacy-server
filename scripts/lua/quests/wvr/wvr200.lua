require ("global")
require ("quest")

--[[

Quest Script

Name:	Hoodwinked
Code:	Wvr200
Id:	110400
Prereq: Level 20, Weaver

The Weavers' Guild welcome at Sunsilk Tapestries. Deaustie signs you on and
sends you to your mentor, Chuchumu, at the Golden Bazaar in Eastern
Thanalan. You find her in tears (wvr20010): a beast tore the red riding
hood her stepmother lent her. Back at Sunsilk, Deaustie gives you the
ripped hood to mend; take the mended hood to the Golden Bazaar, where Lady
Ouvielle has already found her stepdaughter (wvr20020). Deaustie pays you
at Sunsilk (wvr20030): 20,000 gil and 2,000 experience.

The Golden Bazaar scenes play at a push circle (1091160, spawn 31063); the
mended hood has no recipe on this server yet, so it is checked in the bag
as it would come out of a synthesis. Without it the circle stays silent:
the client script has no "not yet" line for that spot.

Journal: steps 63-67 of the quest journal sheet (0B/45/08/4E).

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Find Chuchumu at the Golden Bazaar.
SEQ_010	= 10;  -- Back to Sunsilk Tapestries.
SEQ_012	= 12;  -- Mend the hood and take it to the Golden Bazaar.
SEQ_020	= 20;  -- Back to Deaustie for the reward.

-- Actor Class Ids
ENPC_DEAUSTIE		= 1000293;
ENPC_LOHWAEB		= 1000644;
ENPC_MARGARETE		= 1000645;
ENPC_RINH_MAIMHOV	= 1000646;
ENPC_CAHERNAUT		= 1000915;
ENPC_ASPIPI			= 1000916;
ENPC_GLOIUCEN		= 1000917;
ENPC_BAZAAR_CIRCLE	= 1091160; -- push circle at the Golden Bazaar

ITEM_RED_HOOD		= 11000054; -- red riding hood (crafted)
ITEM_RIPPED_HOOD	= 11000055; -- ripped riding hood (from Deaustie, a synthesis input)

REWARD_GIL	= 20000;
REWARD_EXP	= 2000;

-- Markers (01/03/05/A9: one per cutscene).
MRKR_BAZAAR		= 11040001; -- wvr20010
MRKR_BAZAAR2	= 11040002; -- wvr20020
MRKR_SUNSILK	= 11040003; -- wvr20030

-- At the Golden Bazaar, a few yalms off the circle.
BAZAAR_ZONE = 171;
BAZAAR_SPOT = { 1131.0, 312.2, -1128.0, 2.6 };

-- The weavers' chatter. No speaker is named; slot 2 is Deaustie (her
-- lines point you on), and the other slots go to the Sunsilk weavers in the
-- same order in Wvr300 and Wvr306.
WEAVERS_020 = {
	[ENPC_LOHWAEB] = "processEvent020_2",
	[ENPC_MARGARETE] = "processEvent020_3",
	[ENPC_RINH_MAIMHOV] = "processEvent020_4",
	[ENPC_CAHERNAUT] = "processEvent020_5",
	[ENPC_ASPIPI] = "processEvent020_6",
	[ENPC_GLOIUCEN] = "processEvent020_7",
};

TALKS = {
	[SEQ_000] = {
		[ENPC_DEAUSTIE] = "processEvent005_2",
		[ENPC_LOHWAEB] = "processEvent005_3",
		[ENPC_MARGARETE] = "processEvent005_4",
		[ENPC_RINH_MAIMHOV] = "processEvent005_5",
		[ENPC_CAHERNAUT] = "processEvent005_6",
		[ENPC_ASPIPI] = "processEvent005_7",
		[ENPC_GLOIUCEN] = "processEvent005_8",
	},
	[SEQ_012] = WEAVERS_020,
	[SEQ_020] = WEAVERS_020,
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
		quest:SetENpc(ENPC_BAZAAR_CIRCLE, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_DEAUSTIE, QFLAG_TALK);
	elseif (sequence == SEQ_012) then
		quest:SetENpc(ENPC_DEAUSTIE);
		quest:SetENpc(ENPC_BAZAAR_CIRCLE, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(ENPC_DEAUSTIE, QFLAG_REWARD);
	end
end

local function warpTo(player, zoneId, spot)
	GetWorldManager():DoZoneChange(player, zoneId, nil, 0, 15, spot[1], spot[2], spot[3], spot[4]);
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_DEAUSTIE) then
		-- Join the guild, then meet your mentor (1 = accepted).
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventDeaustieStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_010 and npcClassId == ENPC_DEAUSTIE) then
		-- Deaustie hears of the hood and hands you the ripped one to mend.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010_2");
		player:GetItemPackage(INVENTORY_NORMAL):AddItem(ITEM_RIPPED_HOOD, 1, 1);
		quest:StartSequence(SEQ_012);
	elseif (seq == SEQ_012 and npcClassId == ENPC_DEAUSTIE) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent012_2");
	elseif (seq == SEQ_020 and npcClassId == ENPC_DEAUSTIE) then
		-- wvr20030: the advance on Chuchumu's wages, and payment.
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

	if (npcClassId == ENPC_BAZAAR_CIRCLE and seq == SEQ_000) then
		-- wvr20010: Chuchumu in tears over the torn hood (after-warp fade).
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		quest:StartSequence(SEQ_010);
		player:EndEvent();
		warpTo(player, BAZAAR_ZONE, BAZAAR_SPOT);
		return;
	elseif (npcClassId == ENPC_BAZAAR_CIRCLE and seq == SEQ_012
		and player:GetItemPackage(INVENTORY_NORMAL):HasItem(ITEM_RED_HOOD, 1)) then
		-- wvr20020: too late, Lady Ouvielle is there; the hood calms her
		-- (after-warp fade).
		player:GetItemPackage(INVENTORY_NORMAL):RemoveItem(ITEM_RED_HOOD, 1);
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		quest:StartSequence(SEQ_020);
		player:EndEvent();
		warpTo(player, BAZAAR_ZONE, BAZAAR_SPOT);
		return;
	end
	player:EndEvent();
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:GetSequence();
	if (seq == SEQ_000) then
		return MRKR_BAZAAR;
	elseif (seq == SEQ_012) then
		return MRKR_BAZAAR2;
	elseif (seq == SEQ_010 or seq == SEQ_020) then
		return MRKR_SUNSILK;
	end
end
