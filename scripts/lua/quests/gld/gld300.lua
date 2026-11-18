require ("global")
require ("quest")

--[[

Quest Script

Name:	F'lhaminn's Flower
Code:	Gld300
Id:	110361
Prereq: Level 30, Goldsmith, Gld200

The guild means to reissue F'lhaminn's Flower, Colbernoux's brooch with a
blossom sealed in glass, and Elecotte sends you to Gridania for ten fresh
flowers. The botanists at the Greatloam Growery will not trade with the
goldsmiths (gld30020), but Colbernoux himself is at the Roost: he wants a
single blossom to make one last brooch, and gives you the shattered one
and a violet augite to win a spriggan's help (gld30030). The spriggan
leads you to the flower fields east of Camp Tranquil (gld30040), where a
moogle relents and gives you a pearl clover blossom (gld30050). Colbernoux
takes it at the Roost; back in Ul'dah Elecotte has nothing for one flower
until Colbernoux speaks for you (gld30060). He asks you to take the
mended brooch to F'lhaminn at Amajina & Sons; the Echo shows you its
history (gld30080), and Colbernoux pays 30,000 gil and 3,000 experience.

The spriggan run and the moogle's parley are left out: a push circle at
the clearing plays both scenes back to back. Colbernoux comes to the Roost
by the client's scheduler (processEvent058); in Ul'dah he has the public
spawn in the Lapidaries.

Journal: steps 157-168 of the Ul'dah quest journal sheet (0B/45/08/4E).

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Ask the botanists for flowers.
SEQ_020	= 20;  -- Find Colbernoux at the Roost.
SEQ_030	= 30;  -- Follow the spriggan to the flower fields.
SEQ_050	= 50;  -- Take the blossom to Colbernoux at the Roost.
SEQ_060	= 60;  -- See Elecotte about your reward.
SEQ_065	= 65;  -- Speak with Colbernoux again.
SEQ_070	= 70;  -- Take the mended brooch to F'lhaminn.
SEQ_075	= 75;  -- Use the Echo on F'lhaminn.
SEQ_080	= 80;  -- Tell Colbernoux the brooch was delivered.

-- Actor Class Ids
ENPC_ELECOTTE		= 1000950;
ENPC_COLBERNOUX		= 1000949;
ENPC_OPYLTYL		= 1000236;
ENPC_VKOROLON		= 1000458;
ENPC_FLHAMINN		= 1000038;
ENPC_FIELD_CIRCLE	= 1091180; -- the clearing east of Camp Tranquil
-- Goldsmiths at the Lapidaries
ENPC_HAWAZI_ZOWAZI	= 1000638;
ENPC_ISABELLA		= 1000639;
ENPC_CICEROIX		= 1000640;
ENPC_LEFCHILD		= 1000994;
ENPC_SUNGI_KELUNGI	= 1001022;
ENPC_BOUCHARD		= 1001055;

-- Quest items (journal itemData), key items.
ITEM_VIOLET_AUGITE		= 11000114;
ITEM_SHATTERED_BROOCH	= 11000122;
ITEM_PEARL_CLOVER		= 11000123;
ITEM_FLHAMINNS_FLOWER	= 11000124;

REWARD_GIL	= 30000;
REWARD_EXP	= 3000;

-- Scenes that end on an after-warp fade set you down here.
-- The clearing east of Camp Tranquil (gld30040/30050 cut track).
FIELD_ZONE = 154;
FIELD = { 1500.0, -0.1, 1317.0, 0.0 };
-- In front of Elecotte (gld30060).
GUILD_ZONE = 209;
ELECOTTE_SPOT = { -130.8, 201.6, 258.8, -2.77 };
-- The Concern's stage, by F'lhaminn (gld30080).
STAGE_SPOT = { -92.5, 195.6, 320.5, 0.4 };

-- Map markers (client marker block 11036101): each points at the next
-- cutscene.
MARKERS = {
	[SEQ_000] = { 11036101 };
	[SEQ_020] = { 11036102 };
	[SEQ_030] = { 11036103, 11036104 };
	[SEQ_060] = { 11036105 };
	[SEQ_075] = { 11036106 };
};

-- What people say between steps. The client script names no speaker; the
-- goldsmiths keep the same slots as in Gld200.
TALKS = {
	[SEQ_000] = {
		[ENPC_ELECOTTE] = "processEvent010_2",
		[ENPC_HAWAZI_ZOWAZI] = "processEvent010_3",
		[ENPC_ISABELLA] = "processEvent010_4",
		[ENPC_CICEROIX] = "processEvent010_5",
		[ENPC_LEFCHILD] = "processEvent010_6",
		[ENPC_SUNGI_KELUNGI] = "processEvent010_7",
	},
	[SEQ_020] = {
		[ENPC_OPYLTYL] = "processEvent020_2",
	},
	[SEQ_030] = {
		[ENPC_OPYLTYL] = "processEvent030_2",
	},
	[SEQ_060] = {
		[ENPC_VKOROLON] = "processEvent058_2",
		[ENPC_HAWAZI_ZOWAZI] = "processEvent058_3",
		[ENPC_ISABELLA] = "processEvent058_4",
		[ENPC_CICEROIX] = "processEvent058_5",
		[ENPC_LEFCHILD] = "processEvent058_6",
		[ENPC_SUNGI_KELUNGI] = "processEvent058_7",
	},
	[SEQ_065] = {
		[ENPC_ELECOTTE] = "processEvent060_2",
	},
	[SEQ_070] = {
		[ENPC_COLBERNOUX] = "processEvent067_2",
	},
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_ELECOTTE, QFLAG_TALK);
		return;
	end
	if (TALKS[sequence] ~= nil) then
		for classId, _ in pairs(TALKS[sequence]) do
			quest:SetENpc(classId);
		end
	end
	if (sequence == SEQ_000) then
		quest:SetENpc(ENPC_OPYLTYL, QFLAG_TALK);
	elseif (sequence == SEQ_020 or sequence == SEQ_050) then
		quest:SetENpc(ENPC_VKOROLON, QFLAG_TALK);
	elseif (sequence == SEQ_030) then
		quest:SetENpc(ENPC_FIELD_CIRCLE, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_060) then
		quest:SetENpc(ENPC_ELECOTTE, QFLAG_TALK);
	elseif (sequence == SEQ_065) then
		quest:SetENpc(ENPC_COLBERNOUX, QFLAG_TALK);
	elseif (sequence == SEQ_070 or sequence == SEQ_075) then
		quest:SetENpc(ENPC_FLHAMINN, QFLAG_TALK);
	elseif (sequence == SEQ_080) then
		quest:SetENpc(ENPC_COLBERNOUX, QFLAG_REWARD);
	end
end

local function warpTo(player, zone, spot)
	GetWorldManager():DoZoneChange(player, zone, nil, 0, 15, spot[1], spot[2], spot[3], spot[4]);
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();
	local keyItems = player:GetItemPackage(INVENTORY_KEYITEMS);

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_ELECOTTE) then
		-- The reissue of F'lhaminn's Flower (1 = accepted).
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventElecotteStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and npcClassId == ENPC_OPYLTYL) then
		-- gld30020: the botanists refuse; Colbernoux is at the Roost.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		quest:StartSequence(SEQ_020);
	elseif (seq == SEQ_020 and npcClassId == ENPC_VKOROLON) then
		-- gld30030: Colbernoux's confession; the shattered brooch and the
		-- augite for the spriggan.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
		keyItems:AddItem(ITEM_SHATTERED_BROOCH, 1, 1);
		keyItems:AddItem(ITEM_VIOLET_AUGITE, 1, 1);
		quest:StartSequence(SEQ_030);
	elseif (seq == SEQ_050 and npcClassId == ENPC_VKOROLON) then
		-- V'korolon calls Colbernoux down, and he takes the blossom.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent055");
		callClientFunction(player, "delegateEvent", player, quest, "processEvent058");
		keyItems:RemoveItem(ITEM_PEARL_CLOVER, 1);
		keyItems:RemoveItem(ITEM_VIOLET_AUGITE, 1);
		quest:StartSequence(SEQ_060);
	elseif (seq == SEQ_060 and npcClassId == ENPC_ELECOTTE) then
		-- gld30060: no reward for one flower, until Colbernoux speaks up.
		-- It ends on an after-warp fade.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent060");
		quest:StartSequence(SEQ_065);
		player:EndEvent();
		warpTo(player, GUILD_ZONE, ELECOTTE_SPOT);
		return;
	elseif (seq == SEQ_065 and npcClassId == ENPC_COLBERNOUX) then
		-- The mended brooch, for F'lhaminn.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent067");
		keyItems:RemoveItem(ITEM_SHATTERED_BROOCH, 1);
		keyItems:AddItem(ITEM_FLHAMINNS_FLOWER, 1, 1);
		quest:StartSequence(SEQ_070);
	elseif (seq == SEQ_070 and npcClassId == ENPC_FLHAMINN) then
		-- F'lhaminn takes the brooch.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent075");
		keyItems:RemoveItem(ITEM_FLHAMINNS_FLOWER, 1);
		quest:StartSequence(SEQ_075);
	elseif (seq == SEQ_075 and npcClassId == ENPC_FLHAMINN) then
		-- The Echo (1 = look into her past): gld30080, after-warp fade.
		local echo = callClientFunction(player, "delegateEvent", player, quest, "processEvent078");
		if (echo == 1) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent080");
			quest:StartSequence(SEQ_080);
			player:EndEvent();
			warpTo(player, GUILD_ZONE, STAGE_SPOT);
			return;
		end
	elseif (seq == SEQ_080 and npcClassId == ENPC_COLBERNOUX) then
		-- Colbernoux's thanks, and payment.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent090");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 2);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddGil(REWARD_GIL);
		player:CompleteQuest(quest);
		player:EndEvent();
		return;
	elseif (TALKS[seq] ~= nil and TALKS[seq][npcClassId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, TALKS[seq][npcClassId]);
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (npcClassId == ENPC_FIELD_CIRCLE and seq == SEQ_030) then
		-- gld30040 (the spriggan's run) and gld30050 (the moogle gives
		-- you a blossom), both after-warp fades.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent040");
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050");
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(ITEM_PEARL_CLOVER, 1, 1);
		quest:StartSequence(SEQ_050);
		player:EndEvent();
		warpTo(player, FIELD_ZONE, FIELD);
		return;
	end
	player:EndEvent();
end

function getJournalMapMarkerList(player, quest)
	local markers = MARKERS[quest:GetSequence()];
	if (markers == nil) then
		return nil;
	end
	return unpack(markers);
end
