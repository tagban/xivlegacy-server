require ("global")
require ("quest")

--[[

Quest Script

Name:	The Grass is Always Greener
Code:	Hrv300
Id:	110481
Prereq: Level 30, Botanist, Hrv200

Opyltyl sends you to Ul'dah with a plant specimen for the alchemists
(processEventOpyltylStart, 1 = accepted). Cicely has it, but will only part
with it for a story from Ishgard or Limsa Lominsa for her next letter
(hrv30010). The bard Penelope at the Carline Canopy can't think straight
without a keepsake from afar (processEvent013); Cicely will lend hers, a
pot of nostalgic ink, for a bowing pine branch and a foul-smelling nut
(processEvent014/015). With the ink Penelope tells of a ghost ship
(processEvent017), and Cicely hands over the specimen and a letter for her
friend in Ul'dah (hrv30020). Nogeloix at Frondale's Phrontistery takes the
specimen and sends you to the miners for ceruleum (processEvent025);
at Amajina & Sons Linette and Nenekko take the letter (hrv30030), and
Opyltyl hears the news and pays you (hrv30040): 30,000 gil and 3,000
experience, like the other level-30 guild quests.

The branch and the nut are gathered goods, from two quest-only logging
points in the Central Shroud (gathering points 9120-9121, shown on SEQ_014):
Cicely checks the bag for them and has a line for when they aren't there yet.

Journal: steps 138-144, 188 and 189 of the quest journal sheet.

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Speak with Cicely.
SEQ_010	= 10;  -- Get a story from the bard at the Carline Canopy.
SEQ_013	= 13;  -- Ask Cicely for a keepsake.
SEQ_014	= 14;  -- Bring Cicely a bowing pine branch and a foul-smelling nut.
SEQ_015	= 15;  -- Show the ink to Penelope.
SEQ_017	= 17;  -- Tell Cicely the story.
SEQ_020	= 20;  -- Take the specimen to Frondale's Phrontistery.
SEQ_025	= 25;  -- Ask the miners for ceruleum, and deliver the letter.
SEQ_030	= 30;  -- Report to Opyltyl.

-- Actor Class Ids
ENPC_ONGUEN		= 1000074;
ENPC_OPYLTYL	= 1000236;
ENPC_CICELY		= 1000326;
ENPC_NOGELOIX	= 1000597;
ENPC_EBURHART	= 1000629;
ENPC_LINETTE	= 1000861;
ENPC_VNABYANO	= 1001101;
ENPC_PENELOPE	= 1700001;

-- Items
ITEM_NOSTALGIC_INK	= 11000085; -- Cicely's keepsake (key item)
ITEM_PINE_BRANCH	= 11000086; -- Bowing Pine Branch
ITEM_FOUL_NUT		= 11000087; -- Foul-smelling Nut

-- Quest Markers (each names its scene in the client's marker index; the
-- client has none for Penelope or the Phrontistery)
MRKR_CICELY		= 11048101;
MRKR_GHOST_SHIP	= 11048102;
MRKR_LINETTE	= 11048103;
MRKR_OPYLTYL	= 11048104;

REWARD_GIL	= 30000;
REWARD_EXP	= 3000;

-- Scenes that end on an after-warp fade set you down here.
-- Amajina & Sons Mineral Concern, in front of Linette.
CONCERN_ZONE = 209;
CONCERN = { -94.9, 195.6, 313.8, 1.71 };
-- The Greatloam Growery, in front of Opyltyl.
GROWERY_ZONE = 206;
GROWERY = { -205.6, 20.0, -1457.5, -0.06 };

-- What the botanists say between steps. The client script names no
-- speaker; these follow the lines' content.
TALKS = {
	[SEQ_000] = {
		[ENPC_OPYLTYL] = "processEvent005_2",
		[ENPC_ONGUEN] = "processEvent005_3",
		[ENPC_EBURHART] = "processEvent005_4",
		[ENPC_VNABYANO] = "processEvent005_5",
	},
	[SEQ_010] = {
		[ENPC_CICELY] = "processEvent010_2",
		[ENPC_OPYLTYL] = "processEvent010_3",
	},
	[SEQ_013] = {
		[ENPC_PENELOPE] = "processEvent013_2",
	},
	[SEQ_014] = {
		[ENPC_PENELOPE] = "processEvent013_2",
	},
	[SEQ_015] = {
		[ENPC_CICELY] = "processEvent015_2",
	},
	[SEQ_017] = {
		[ENPC_PENELOPE] = "processEvent018",
		[ENPC_EBURHART] = "processEvent017_2",
	},
	[SEQ_020] = {
		[ENPC_CICELY] = "processEvent020_2",
		[ENPC_ONGUEN] = "processEvent020_3",
		[ENPC_EBURHART] = "processEvent020_4",
		[ENPC_VNABYANO] = "processEvent020_5",
		[ENPC_LINETTE] = "processEvent020_6",
	},
	[SEQ_025] = {
		[ENPC_NOGELOIX] = "processEvent025_2",
	},
	[SEQ_030] = {
		[ENPC_LINETTE] = "processEvent030_2",
		[ENPC_ONGUEN] = "processEvent030_3",
		[ENPC_EBURHART] = "processEvent030_4",
		[ENPC_VNABYANO] = "processEvent030_5",
	},
};

-- Who moves the quest on in each sequence.
TARGETS = {
	[SEQ_000] = ENPC_CICELY,
	[SEQ_010] = ENPC_PENELOPE,
	[SEQ_013] = ENPC_CICELY,
	[SEQ_014] = ENPC_CICELY,
	[SEQ_015] = ENPC_PENELOPE,
	[SEQ_017] = ENPC_CICELY,
	[SEQ_020] = ENPC_NOGELOIX,
	[SEQ_025] = ENPC_LINETTE,
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
	elseif (sequence == SEQ_030) then
		quest:SetENpc(ENPC_OPYLTYL, QFLAG_REWARD);
	end
end

local function warpTo(player, zoneId, spot)
	GetWorldManager():DoZoneChange(player, zoneId, nil, 0, 15, spot[1], spot[2], spot[3], spot[4]);
end

local function delegate(player, quest, fn)
	callClientFunction(player, "delegateEvent", player, quest, fn);
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_OPYLTYL) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventOpyltylStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and npcClassId == ENPC_CICELY) then
		-- hrv30010: no specimen without a story.
		delegate(player, quest, "processEvent010");
		quest:StartSequence(SEQ_010);
	elseif (seq == SEQ_010 and npcClassId == ENPC_PENELOPE) then
		-- Penelope needs a keepsake from afar to clear her head.
		delegate(player, quest, "processEvent013");
		quest:StartSequence(SEQ_013);
	elseif (seq == SEQ_013 and npcClassId == ENPC_CICELY) then
		-- Cicely will lend her ink, for a branch and a nut.
		delegate(player, quest, "processEvent014");
		quest:StartSequence(SEQ_014);
	elseif (seq == SEQ_014 and npcClassId == ENPC_CICELY) then
		local bag = player:GetItemPackage(INVENTORY_NORMAL);
		if (bag:HasItem(ITEM_PINE_BRANCH, 1) and bag:HasItem(ITEM_FOUL_NUT, 1)) then
			delegate(player, quest, "processEvent015");
			bag:RemoveItem(ITEM_PINE_BRANCH, 1);
			bag:RemoveItem(ITEM_FOUL_NUT, 1);
			player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(ITEM_NOSTALGIC_INK, 1, 1);
			quest:StartSequence(SEQ_015);
		else
			-- Not yet: she repeats what she wants.
			delegate(player, quest, "processEvent014_2");
		end
	elseif (seq == SEQ_015 and npcClassId == ENPC_PENELOPE) then
		-- The ghost ship of Limsa Lominsa.
		delegate(player, quest, "processEvent017");
		quest:StartSequence(SEQ_017);
	elseif (seq == SEQ_017 and npcClassId == ENPC_CICELY) then
		-- hrv30020: the story told, the ink back, the specimen and letter.
		delegate(player, quest, "processEvent020");
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(ITEM_NOSTALGIC_INK, 1);
		quest:StartSequence(SEQ_020);
	elseif (seq == SEQ_020 and npcClassId == ENPC_NOGELOIX) then
		-- The specimen delivered; ask the miners for ceruleum.
		delegate(player, quest, "processEvent025");
		quest:StartSequence(SEQ_025);
	elseif (seq == SEQ_025 and npcClassId == ENPC_LINETTE) then
		-- hrv30030: Nenekko's letter, and a sample of ceruleum. It ends on
		-- an after-warp fade.
		delegate(player, quest, "processEvent030");
		quest:StartSequence(SEQ_030);
		player:EndEvent();
		warpTo(player, CONCERN_ZONE, CONCERN);
		return;
	elseif (seq == SEQ_030 and npcClassId == ENPC_OPYLTYL) then
		-- hrv30040: the report, and payment. It ends on an after-warp fade.
		delegate(player, quest, "processEvent040");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 2);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddGil(REWARD_GIL);
		player:CompleteQuest(quest);
		player:EndEvent();
		warpTo(player, GROWERY_ZONE, GROWERY);
		return;
	elseif (TALKS[seq] ~= nil and TALKS[seq][npcClassId] ~= nil) then
		delegate(player, quest, TALKS[seq][npcClassId]);
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc, eventName)
	player:EndEvent();
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_000) then
		return MRKR_CICELY;
	elseif (seq == SEQ_017) then
		return MRKR_GHOST_SHIP;
	elseif (seq == SEQ_025) then
		return MRKR_LINETTE;
	elseif (seq == SEQ_030) then
		return MRKR_OPYLTYL;
	end
end
