require ("global")
require ("quest")

--[[

Quest Script

Name:	An Ear for Quality
Code:	Bsm200
Id:	110320
Prereq: Level 20, Blacksmith

The Blacksmiths' Guild's welcome at Naldiq & Vymelli's. Bodenolf signs you
on and sends you up to Mimidoa, the half-deaf old smith on the balcony.
Mimidoa sets you a test (bsm20010): a Naldiq gramophone case from two bronze
ingots. Not good enough, he says, and sends you to Iofa for the recipe of a
Naldiq trembler (three bronze ingots). Bring him the trembler (bsm20020)
for 20,000 gil and 2,000 experience.

The client script also carries the armorer's branch (Vymelli pieces, the
recipes from Trinne and Syngsmyd) and the better-quality answers (coil,
horn); the journal follows the smith's lowest branch, so only that one is
scripted.

Mimidoa only stands in instances in 1.23b; here he has a public spawn on the
balcony (spawn 31040). The quest pieces have no recipe on this server yet,
so they are checked in the bag as they would come out of a synthesis.

Journal: steps 111-114 of the quest journal sheet (0B/45/08/1B).

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Speak with Mimidoa.
SEQ_010	= 10;  -- Make Mimidoa a gramophone case.
SEQ_015	= 15;  -- Make him a trembler (Iofa has the recipe).

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

-- Quest pieces (journal itemData).
ITEM_GRAMOPHONE_CASE	= 11000004; -- Naldiq gramophone case
ITEM_TREMBLER			= 11000005; -- Naldiq trembler

FLAG_IOFA_RECIPE	= 0; -- Iofa has given the trembler's recipe

REWARD_GIL	= 20000;
REWARD_EXP	= 2000;

-- In front of Mimidoa on the forge balcony (his spawn faces 0.793).
GUILD_ZONE = 230;
MIMIDOA_SPOT = { -482.25, 44.5, 405.92, -2.35 };

-- The forge's word for a new hand. The client script names no speaker; the
-- same slot numbers recur in Bsm300/Bsm306, so they are given to the same
-- smiths there (Bodenolf takes slot 2, the Lalafell twins 8 and 9).
TALKS = {
	[SEQ_000] = {
		[ENPC_BODENOLF] = "processEvent005_2",
		[ENPC_CARRILAUT] = "processEvent005_3",
		[ENPC_MZIMZIZI] = "processEvent005_4",
		[ENPC_IOFA] = "processEvent005_5",
		[ENPC_MARTIALLAIS] = "processEvent005_6",
		[ENPC_PFYNHAEMR] = "processEvent005_7",
		[ENPC_SOSOZE] = "processEvent005_8",
		[ENPC_HIHINE] = "processEvent005_9",
		[ENPC_SATHZANT] = "processEvent005_10",
		[ENPC_GAUTZELIN] = "processEvent005_11",
	},
	[SEQ_010] = {
		[ENPC_BODENOLF] = "processEvent010_2",
		[ENPC_CARRILAUT] = "processEvent010_3",
		[ENPC_MZIMZIZI] = "processEvent010_4",
		[ENPC_IOFA] = "processEvent010_5",
		[ENPC_MARTIALLAIS] = "processEvent010_6",
		[ENPC_PFYNHAEMR] = "processEvent010_7",
	},
	[SEQ_015] = {
		[ENPC_BODENOLF] = "processEvent010_2",
		[ENPC_CARRILAUT] = "processEvent010_3",
		[ENPC_MZIMZIZI] = "processEvent010_4",
		[ENPC_MARTIALLAIS] = "processEvent010_6",
		[ENPC_PFYNHAEMR] = "processEvent010_7",
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
	if (sequence == SEQ_000 or sequence == SEQ_010) then
		quest:SetENpc(ENPC_MIMIDOA, QFLAG_TALK);
	elseif (sequence == SEQ_015) then
		local recipe = quest:GetData():GetFlag(FLAG_IOFA_RECIPE);
		quest:SetENpc(ENPC_IOFA, recipe and QFLAG_OFF or QFLAG_TALK);
		quest:SetENpc(ENPC_MIMIDOA, QFLAG_REWARD);
	end
end

local function warpTo(player, spot)
	GetWorldManager():DoZoneChange(player, GUILD_ZONE, nil, 0, 15, spot[1], spot[2], spot[3], spot[4]);
end

local function hasItem(player, itemId)
	return player:GetItemPackage(INVENTORY_NORMAL):HasItem(itemId, 1);
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_BODENOLF) then
		-- Join the guild, and go up to Mimidoa (1 = accepted). It ends on
		-- an after-warp fade.
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventBodenolfStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
			player:EndEvent();
			warpTo(player, MIMIDOA_SPOT);
			return;
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and npcClassId == ENPC_BODENOLF) then
		-- Bodenolf again: go up to Mimidoa now? (after-warp fade on yes)
		local go = callClientFunction(player, "delegateEvent", player, quest, "processEvent005");
		if (go == 1) then
			player:EndEvent();
			warpTo(player, MIMIDOA_SPOT);
			return;
		end
	elseif (seq == SEQ_000 and npcClassId == ENPC_MIMIDOA) then
		-- bsm20010: Mimidoa's test and the gramophone case's recipe.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		quest:StartSequence(SEQ_010);
	elseif (seq == SEQ_010 and npcClassId == ENPC_MIMIDOA) then
		if (hasItem(player, ITEM_GRAMOPHONE_CASE)) then
			-- Not good enough: practice on a trembler; Iofa has the recipe.
			player:GetItemPackage(INVENTORY_NORMAL):RemoveItem(ITEM_GRAMOPHONE_CASE, 1);
			callClientFunction(player, "delegateEvent", player, quest, "processEventS010_1");
			quest:StartSequence(SEQ_015);
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent007_2");
		end
	elseif (seq == SEQ_015 and npcClassId == ENPC_IOFA) then
		if (quest:GetData():GetFlag(FLAG_IOFA_RECIPE)) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent018_1");
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEventS015_1");
			quest:GetData():SetFlag(FLAG_IOFA_RECIPE);
			quest:SetENpc(ENPC_IOFA, QFLAG_OFF);
		end
	elseif (seq == SEQ_015 and npcClassId == ENPC_MIMIDOA) then
		if (hasItem(player, ITEM_TREMBLER)) then
			-- bsm20020: the final judgement, and payment. It ends on an
			-- after-warp fade.
			player:GetItemPackage(INVENTORY_NORMAL):RemoveItem(ITEM_TREMBLER, 1);
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 2);
			player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
			player:AddGil(REWARD_GIL);
			player:CompleteQuest(quest);
			player:EndEvent();
			warpTo(player, MIMIDOA_SPOT);
			return;
		end
		callClientFunction(player, "delegateEvent", player, quest, "processEventS010_7");
	elseif (TALKS[seq] ~= nil and TALKS[seq][npcClassId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, TALKS[seq][npcClassId]);
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc, eventName)
	player:EndEvent();
end

function getJournalMapMarkerList(player, quest)
	return {};
end
