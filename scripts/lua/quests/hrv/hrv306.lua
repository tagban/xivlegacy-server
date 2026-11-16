require ("global")
require ("quest")

--[[

Quest Script

Name:	A Moogle Bouquet
Code:	Hrv306
Id:	110482
Prereq: Level 36, Botanist, Hrv300

Moogles have been attacked in the wood again, and Opyltyl sends you to help
Sister Rychyld of the conjurers (processEventOpyltylStart, 1 = accepted).
She sizes you up at the Growery (hrv30610: answer her questions well and
she asks you to the flower beds south of Camp Crimson Bark), meets you
there (hrv30620) and has you gather a handful of pearl clover seeds
(hrv30630). Cicely tells you to plant and raise them (processEvent032), the
botanists send you to Opyltyl, who wants yarzon dung from the sleeping
yarzons near Humblehearth for fertilizer (processEvent034). With the dung
the seeds bud (processEvent038); the Echo on Cicely shows her raising the
same flower for her friend in Ul'dah (hrv30640), Opyltyl hands over the
blossoms (processEvent045), Cicely sends you to Rychyld with them
(hrv30650), the moogles gather round the flowers (hrv30660), and Cicely
pays you back at the Growery (hrv30670): 36,000 gil and 3,600 experience,
like the other level-36 guild quests.

Rychyld has no class path in 1.23b, so her meetings are push circles. The
yarzon dung is a gathered good: Opyltyl checks the bag for it and repeats
his request when it isn't there yet. The pearl clover blossom is a key item.

Journal: steps 145-156 of the quest journal sheet.

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Speak with Sister Rychyld.
SEQ_010	= 10;  -- Meet her at the flower beds south of Camp Crimson Bark.
SEQ_020	= 20;  -- Gather pearl clover seeds.
SEQ_030	= 30;  -- Back to the Growery; speak with Cicely.
SEQ_032	= 32;  -- Ask the botanists how to grow them.
SEQ_034	= 34;  -- Bring Opyltyl yarzon dung.
SEQ_040	= 40;  -- Report to Cicely (the Echo).
SEQ_045	= 45;  -- Fetch the seedlings from Opyltyl.
SEQ_050	= 50;  -- Show them to Cicely.
SEQ_060	= 60;  -- Take them to Sister Rychyld.
SEQ_070	= 70;  -- Report to Cicely.

-- Actor Class Ids
ENPC_ONGUEN			= 1000074;
ENPC_OPYLTYL		= 1000236;
ENPC_CICELY			= 1000326;
ENPC_EBURHART		= 1000629;
ENPC_VNABYANO		= 1001101;
ENPC_SANDRE			= 1001102;
ENPC_RYCHYLD_GROWERY	= 1091121; -- push circles where Rychyld waits
ENPC_FLOWER_BEDS	= 1091122;
ENPC_MOOGLE_BEDS	= 1091123;

-- Items
ITEM_YARZON_DUNG	= 11000043; -- Yarzon Faeces
ITEM_PEARL_CLOVER	= 11000123; -- Pearl Clover Blossom (key item)

-- Quest Markers (each names its scene in the client's marker index)
MRKR_RYCHYLD		= 11048201;
MRKR_FLOWER_BEDS	= 11048202;
MRKR_SEEDS			= 11048203;
MRKR_BACK_TO_CICELY	= 11048204;
MRKR_ECHO			= 11048205;
MRKR_BLOSSOMS		= 11048206;
MRKR_MOOGLES		= 11048207;
MRKR_REWARD			= 11048208;

REWARD_GIL	= 36000;
REWARD_EXP	= 3600;

-- Scenes that end on an after-warp fade set you down here.
-- The Greatloam Growery, in front of Opyltyl.
GROWERY_ZONE = 206;
GROWERY = { -205.6, 20.0, -1457.5, -0.06 };
-- West Shroud, beside the flower beds (scene positions; heights from the
-- client's ground mesh).
FLOWER_BEDS_ZONE = 153;
FLOWER_BEDS = { -1305.0, -0.25, -219.0, -0.9 };

-- What the botanists say between steps. The client script names no
-- speaker; these follow the lines' content.
TALKS = {
	[SEQ_000] = {
		[ENPC_OPYLTYL] = "processEvent005_2",
		[ENPC_ONGUEN] = "processEvent005_3",
		[ENPC_EBURHART] = "processEvent005_4",
		[ENPC_VNABYANO] = "processEvent005_5",
		[ENPC_SANDRE] = "processEvent005_6",
	},
	[SEQ_010] = {
		[ENPC_OPYLTYL] = "processEvent010_2",
		[ENPC_CICELY] = "processEvent010_3",
	},
	[SEQ_030] = {
		[ENPC_OPYLTYL] = "processEvent030_2",
	},
	[SEQ_032] = {
		[ENPC_CICELY] = "processEvent032_2",
		[ENPC_ONGUEN] = "processEvent032_3",
		[ENPC_EBURHART] = "processEvent032_4",
		[ENPC_VNABYANO] = "processEvent032_5",
	},
	[SEQ_034] = {
		[ENPC_ONGUEN] = "processEvent034_3",
		[ENPC_EBURHART] = "processEvent034_4",
		[ENPC_VNABYANO] = "processEvent034_5",
	},
	[SEQ_040] = {
		[ENPC_OPYLTYL] = "processEvent038_2",
	},
	[SEQ_045] = {
		[ENPC_CICELY] = "processEvent040_2",
	},
	[SEQ_060] = {
		[ENPC_OPYLTYL] = "processEvent050_2",
		[ENPC_CICELY] = "processEvent050_3",
	},
};

-- Who moves the quest on in each sequence (by talking).
TARGETS = {
	[SEQ_030] = ENPC_CICELY,
	[SEQ_032] = ENPC_OPYLTYL,
	[SEQ_034] = ENPC_OPYLTYL,
	[SEQ_040] = ENPC_CICELY,
	[SEQ_045] = ENPC_OPYLTYL,
	[SEQ_050] = ENPC_CICELY,
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_OPYLTYL, QFLAG_TALK);
		return;
	end
	if (TALKS[sequence] ~= nil) then
		for classId, _ in pairs(TALKS[sequence]) do
			quest:SetENpc(classId);
		end
	end
	if (TARGETS[sequence] ~= nil) then
		quest:SetENpc(TARGETS[sequence], QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		-- Stays open: answering her badly leaves her waiting.
		quest:SetENpc(ENPC_RYCHYLD_GROWERY, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_010 or sequence == SEQ_020) then
		quest:SetENpc(ENPC_FLOWER_BEDS, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_060) then
		quest:SetENpc(ENPC_MOOGLE_BEDS, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_070) then
		quest:SetENpc(ENPC_CICELY, QFLAG_REWARD);
	end
end

local function warpTo(player, zoneId, spot)
	GetWorldManager():DoZoneChange(player, zoneId, nil, 0, 15, spot[1], spot[2], spot[3], spot[4]);
end

local function delegate(player, quest, fn, ...)
	return callClientFunction(player, "delegateEvent", player, quest, fn, ...);
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_OPYLTYL) then
		local accepted = delegate(player, quest, "processEventOpyltylStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_030 and npcClassId == ENPC_CICELY) then
		-- Plant the seeds and raise them.
		delegate(player, quest, "processEvent032");
		quest:StartSequence(SEQ_032);
	elseif (seq == SEQ_032 and npcClassId == ENPC_OPYLTYL) then
		-- The fertilizer: yarzon dung from near Humblehearth.
		delegate(player, quest, "processEvent034");
		quest:StartSequence(SEQ_034);
	elseif (seq == SEQ_034 and npcClassId == ENPC_OPYLTYL) then
		local bag = player:GetItemPackage(INVENTORY_NORMAL);
		if (bag:HasItem(ITEM_YARZON_DUNG, 1)) then
			-- The seeds have budded; go and tell Cicely.
			delegate(player, quest, "processEvent038");
			bag:RemoveItem(ITEM_YARZON_DUNG, 1);
			quest:StartSequence(SEQ_040);
		else
			-- Not yet: he repeats where to find it.
			delegate(player, quest, "processEvent034_2");
		end
	elseif (seq == SEQ_040 and npcClassId == ENPC_CICELY) then
		-- The Echo on Cicely (hrv30640). Turning it down leaves her be.
		local echo = delegate(player, quest, "processEvent040");
		if (echo == 1) then
			quest:StartSequence(SEQ_045);
		end
	elseif (seq == SEQ_045 and npcClassId == ENPC_OPYLTYL) then
		-- The seedlings in bloom.
		delegate(player, quest, "processEvent045");
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(ITEM_PEARL_CLOVER, 1, 1);
		quest:StartSequence(SEQ_050);
	elseif (seq == SEQ_050 and npcClassId == ENPC_CICELY) then
		-- hrv30650: take them to Rychyld.
		delegate(player, quest, "processEvent050");
		quest:StartSequence(SEQ_060);
	elseif (seq == SEQ_070 and npcClassId == ENPC_CICELY) then
		-- hrv30670: Cicely's thanks, and payment.
		delegate(player, quest, "processEvent070");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 2);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddGil(REWARD_GIL);
		player:CompleteQuest(quest);
	elseif (TALKS[seq] ~= nil and TALKS[seq][npcClassId] ~= nil) then
		delegate(player, quest, TALKS[seq][npcClassId]);
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (npcClassId == ENPC_RYCHYLD_GROWERY and seq == SEQ_000) then
		-- hrv30610: Rychyld's questions. 1 = she takes you on (after-warp
		-- fade); anything else leaves her waiting.
		local passed = delegate(player, quest, "processEvent010");
		if (passed == 1) then
			quest:StartSequence(SEQ_010);
			player:EndEvent();
			warpTo(player, GROWERY_ZONE, GROWERY);
			return;
		end
	elseif (npcClassId == ENPC_FLOWER_BEDS and seq == SEQ_010) then
		-- hrv30620: the moogles' leave to gather seeds. After-warp fade.
		delegate(player, quest, "processEvent020");
		quest:StartSequence(SEQ_020);
		player:EndEvent();
		warpTo(player, FLOWER_BEDS_ZONE, FLOWER_BEDS);
		return;
	elseif (npcClassId == ENPC_FLOWER_BEDS and seq == SEQ_020) then
		-- hrv30630: just enough seeds (0 = not too many). After-warp fade.
		delegate(player, quest, "processEvent030", 0);
		quest:StartSequence(SEQ_030);
		player:EndEvent();
		warpTo(player, FLOWER_BEDS_ZONE, FLOWER_BEDS);
		return;
	elseif (npcClassId == ENPC_MOOGLE_BEDS and seq == SEQ_060) then
		-- hrv30660: the moogles and their flower beds.
		delegate(player, quest, "processEvent060");
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(ITEM_PEARL_CLOVER, 1);
		quest:StartSequence(SEQ_070);
	end
	quest:UpdateENPCs();
	player:EndEvent();
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_000) then
		return MRKR_RYCHYLD;
	elseif (seq == SEQ_010) then
		return MRKR_FLOWER_BEDS;
	elseif (seq == SEQ_020) then
		return MRKR_SEEDS;
	elseif (seq == SEQ_030) then
		return MRKR_BACK_TO_CICELY;
	elseif (seq == SEQ_040) then
		return MRKR_ECHO;
	elseif (seq == SEQ_050) then
		return MRKR_BLOSSOMS;
	elseif (seq == SEQ_060) then
		return MRKR_MOOGLES;
	elseif (seq == SEQ_070) then
		return MRKR_REWARD;
	end
end
