require ("global")
require ("quest")

--[[

Quest Script

Name:	Song of the Sirens
Code:	Bsm300
Id:	110321
Prereq: Level 30, Blacksmith

Siren rumors have every smith at Naldiq & Vymelli's hammering out Mimidoa's
whistling windwheels, and the forge is short of ore. Mimidoa sends you to
Amajina & Sons in Ul'dah for a crate of it; Linette turns you away, and
Mimidoa, over the linkpearl, sends you to the Nanawa Mines to trade for it
at the source. Z'ssapa meets you with a cave-in (bsm30010); you keep the
trapped miners talking until the rubble is cleared, and the grateful miners
give you the ore (bsm30020). Mimidoa hands you a windwheel for the captain
of the Vesper Bay ferry; you ride along through the sirens' waters
(bsm30030), and tell Mimidoa which melody you heard for 30,000 gil and
3,000 experience.

Simplified here: Mimidoa's linkpearl call (processEvent006) plays right
after Linette's refusal; the parley with the panicking miners (the
processEventS001-S003 lines) is left out, as the miners have no actors; the
trapped miner, Z'ssapa and the ferry captain have no class path in 1.23b, so
they are push circles (1091140-1091142). Mimidoa has a public spawn on the
forge balcony (31040).

Journal: steps 93-103 of the quest journal sheet (0B/45/08/1B).

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Speak with Mimidoa.
SEQ_003	= 3;   -- Fetch the ore from Amajina & Sons in Ul'dah.
SEQ_006	= 6;   -- Go to the source: the Nanawa Mines.
SEQ_009	= 9;   -- Help the miners trapped by the cave-in.
SEQ_015	= 15;  -- Back to Mimidoa with the ore.
SEQ_020	= 20;  -- Deliver the windwheel to the ferry captain.
SEQ_030	= 30;  -- Tell Mimidoa how it went.

-- Actor Class Ids
ENPC_BODENOLF		= 1000144;
ENPC_MIMIDOA		= 1000176;
ENPC_IOFA			= 1000135;
ENPC_PFYNHAEMR		= 1000060;
ENPC_MZIMZIZI		= 1000061;
ENPC_CARRILAUT		= 1000062;
ENPC_MARTIALLAIS	= 1000134;
ENPC_SOSOZE			= 1000265;
ENPC_HIHINE			= 1000267;
ENPC_SATHZANT		= 1000338;
ENPC_GAUTZELIN		= 1000365;
ENPC_LINETTE		= 1000861; -- Amajina & Sons, Ul'dah
ENPC_ZSSAPA_CIRCLE	= 1091140; -- push circle inside the Nanawa Mines entrance
ENPC_CAVEIN_CIRCLE	= 1091141; -- push circle at the rubble
ENPC_FERRY_CIRCLE	= 1091142; -- push circle at the Limsa ferry docks

ITEM_WINDWHEEL	= 11000022; -- whistling windwheel (key item)

REWARD_GIL	= 30000;
REWARD_EXP	= 3000;

-- In front of Mimidoa on the forge balcony.
LIMSA_ZONE = 230;
MIMIDOA_SPOT = { -482.25, 44.5, 405.92, -2.35 };
FERRY_DOCKS = { -838.0, 6.0, 238.0, 1.57 };
-- Nanawa Mines: the zone-in point and the rubble.
MINES_ZONE = 176;
MINES_ENTRANCE = { 109.0, 174.54, -1125.0, 2.622 };
MINES_RUBBLE = { 86.0, 168.0, -1275.0, 3.14 };

-- The forge's chatter. No speaker is named; the slots go to the same smiths
-- as in Bsm200 (the "_7_1" variant is the smith's, "_7_2" the armorer's).
-- 003_10 is Mimidoa's own reminder.
TALKS = {
	[SEQ_000] = {
		[ENPC_BODENOLF] = "processEvent001_2",
		[ENPC_CARRILAUT] = "processEvent001_3",
		[ENPC_MZIMZIZI] = "processEvent001_4",
		[ENPC_IOFA] = "processEvent001_5",
		[ENPC_MARTIALLAIS] = "processEvent001_6",
		[ENPC_PFYNHAEMR] = "processEvent001_7_1",
		[ENPC_SOSOZE] = "processEvent001_8",
		[ENPC_HIHINE] = "processEvent001_9",
		[ENPC_SATHZANT] = "processEvent001_10",
		[ENPC_GAUTZELIN] = "processEvent001_11",
	},
	[SEQ_003] = {
		[ENPC_BODENOLF] = "processEvent003_2",
		[ENPC_CARRILAUT] = "processEvent003_3",
		[ENPC_MZIMZIZI] = "processEvent003_4",
		[ENPC_IOFA] = "processEvent003_5",
		[ENPC_MARTIALLAIS] = "processEvent003_6",
		[ENPC_PFYNHAEMR] = "processEvent003_7",
		[ENPC_SOSOZE] = "processEvent003_8",
		[ENPC_HIHINE] = "processEvent003_9",
		[ENPC_MIMIDOA] = "processEvent003_10",
	},
	[SEQ_006] = {
		[ENPC_LINETTE] = "processEvent004_2",
	},
	[SEQ_009] = {
		[ENPC_LINETTE] = "processEvent004_2",
	},
	[SEQ_015] = {
		[ENPC_BODENOLF] = "processEvent010_2",
		[ENPC_CARRILAUT] = "processEvent010_3",
		[ENPC_MZIMZIZI] = "processEvent010_4",
		[ENPC_IOFA] = "processEvent010_5",
	},
	[SEQ_030] = {
		[ENPC_BODENOLF] = "processEvent030_2",
		[ENPC_CARRILAUT] = "processEvent030_3",
		[ENPC_MZIMZIZI] = "processEvent030_4",
		[ENPC_IOFA] = "processEvent030_5",
		[ENPC_MARTIALLAIS] = "processEvent030_6",
		[ENPC_PFYNHAEMR] = "processEvent030_7",
		[ENPC_SOSOZE] = "processEvent030_8",
		[ENPC_HIHINE] = "processEvent030_9",
	},
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_BODENOLF, QFLAG_TALK);
		return;
	end
	if (TALKS[sequence] ~= nil) then
		for classId, _ in pairs(TALKS[sequence]) do
			quest:SetENpc(classId);
		end
	end
	if (sequence == SEQ_000 or sequence == SEQ_015) then
		quest:SetENpc(ENPC_MIMIDOA, QFLAG_TALK);
	elseif (sequence == SEQ_003) then
		quest:SetENpc(ENPC_LINETTE, QFLAG_TALK);
	elseif (sequence == SEQ_006) then
		quest:SetENpc(ENPC_ZSSAPA_CIRCLE, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_009) then
		quest:SetENpc(ENPC_CAVEIN_CIRCLE, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(ENPC_FERRY_CIRCLE, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_030) then
		quest:SetENpc(ENPC_MIMIDOA, QFLAG_REWARD);
	end
end

local function warpTo(player, zoneId, spot)
	GetWorldManager():DoZoneChange(player, zoneId, nil, 0, 15, spot[1], spot[2], spot[3], spot[4]);
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_BODENOLF) then
		-- Mimidoa needs a hand (1 = accepted). It ends on an after-warp fade.
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventBodenolfStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
			player:EndEvent();
			warpTo(player, LIMSA_ZONE, MIMIDOA_SPOT);
			return;
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and npcClassId == ENPC_MIMIDOA) then
		-- The sirens, the windwheels, and the errand to Ul'dah.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent003");
		quest:StartSequence(SEQ_003);
	elseif (seq == SEQ_003 and npcClassId == ENPC_LINETTE) then
		-- The Syndicate won't clear the ore for export; Mimidoa, over the
		-- linkpearl, points you at the Nanawa Mines.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent004_1");
		callClientFunction(player, "delegateEvent", player, quest, "processEvent006");
		quest:StartSequence(SEQ_006);
	elseif (seq == SEQ_015 and npcClassId == ENPC_MIMIDOA) then
		-- The ore handed over; take a windwheel to the ferry captain. It
		-- ends on an after-warp fade.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent015");
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(ITEM_WINDWHEEL, 1, 1);
		quest:StartSequence(SEQ_020);
		player:EndEvent();
		warpTo(player, LIMSA_ZONE, MIMIDOA_SPOT);
		return;
	elseif (seq == SEQ_030 and npcClassId == ENPC_MIMIDOA) then
		-- Which melody did you hear? Then payment.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent040");
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

	if (npcClassId == ENPC_ZSSAPA_CIRCLE and seq == SEQ_006) then
		-- Z'ssapa and the cave-in, then into the caverns (bsm30010, after-
		-- warp fade).
		callClientFunction(player, "delegateEvent", player, quest, "processEvent007");
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		quest:StartSequence(SEQ_009);
		player:EndEvent();
		warpTo(player, MINES_ZONE, MINES_ENTRANCE);
		return;
	elseif (npcClassId == ENPC_CAVEIN_CIRCLE and seq == SEQ_009) then
		-- The miner behind the rubble, then the rescue and the ore
		-- (bsm30020, after-warp fade).
		callClientFunction(player, "delegateEvent", player, quest, "processEvent009");
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		quest:StartSequence(SEQ_015);
		player:EndEvent();
		warpTo(player, MINES_ZONE, MINES_RUBBLE);
		return;
	elseif (npcClassId == ENPC_FERRY_CIRCLE and seq == SEQ_020) then
		-- The ferry captain and the voyage past the sirens (bsm30030,
		-- after-warp fade).
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(ITEM_WINDWHEEL, 1);
		quest:StartSequence(SEQ_030);
		player:EndEvent();
		warpTo(player, LIMSA_ZONE, FERRY_DOCKS);
		return;
	end
	player:EndEvent();
end

function getJournalMapMarkerList(player, quest)
	return {};
end
