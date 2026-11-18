require ("global")
require ("quest")

--[[

Quest Script

Name:	A Piece of History
Code:	Min200
Id:	110460
Prereq: Level 20, Miner

The Miners' Guild's welcome at Amajina & Sons. Linette signs you on and
sends you to the Nanawa Mines, where Z'ssapa keeps the entrance and the
guildmaster's twin sons, Popokkuli and Seserukka, want proof of your worth
before they let you in (min20010): dig up something rare in Thanalan and
bring it to Z'ssapa. Of what you bring her, an old ceramic shard catches
the eye of Nenekko, who knows it for Sil'dihn (min20020); the twins burst
in, and she turns out to be their sister (min20030). See her home
(min20035); she keeps the shard and promises to speak to her brothers.
Linette pays 20,000 gil and 2,000 experience.

Z'ssapa and Nenekko only stood in instances in 1.23b; here they have
public spawns at the mine entrance. The three finds are quest-only
gathered items with no node on this server yet; they are checked in the
bag. Their item ids are a guess: the client's journal names none, and
these are the three dummy items (a stone, a fossil, a ewer shard) that
match Z'ssapa's three appraisals.

Journal: steps 1-5 and 272 of the Ul'dah quest journal sheet (0B/45/08/4E).

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Go to the Nanawa Mines and speak with Z'ssapa.
SEQ_015	= 15;  -- Prospect in Thanalan and bring your finds to Z'ssapa.
SEQ_020	= 20;  -- Speak with Nenekko.
SEQ_035	= 35;  -- See Nenekko home.
SEQ_040	= 40;  -- Return to Amajina & Sons.

-- Actor Class Ids
ENPC_LINETTE		= 1000861;
ENPC_ZSSAPA			= 1000887;
ENPC_NENEKKO		= 1000888;
-- Miners at the Concern
ENPC_MOHTFRYD		= 1001170;
ENPC_PIERRIQUET		= 1001169;
ENPC_YUYUBESU		= 1001166;
ENPC_CHACHAI		= 1001167;
ENPC_FIFILO			= 1001168;
ENPC_MUMUKIYA		= 1001165;

-- The finds (guessed ids, see above), each appraised once.
ITEM_SHEEPS_EYE		= 11000012;
ITEM_PETRIFIED_WOOD	= 11000013;
ITEM_EWER_FRAGMENT	= 11000014; -- the Sil'dihn shard
FINDS = {
	{ item = ITEM_PETRIFIED_WOOD, flag = 0, event = "processEvent017_A" },
	{ item = ITEM_SHEEPS_EYE, flag = 1, event = "processEvent017_B" },
	{ item = ITEM_EWER_FRAGMENT, flag = 2, event = "processEvent017_C" },
};

REWARD_GIL	= 20000;
REWARD_EXP	= 2000;

-- Scenes that end on an after-warp fade set you down here.
-- The Nanawa Mines entrance, by Z'ssapa (min20020, min20030).
MINES_ZONE = 176;
MINES_ENTRANCE = { 106.0, 174.5, -1123.0, 2.6 };
-- The Concern, in front of Linette (min20035).
CONCERN_ZONE = 209;
CONCERN = { -94.9, 195.6, 313.8, 1.71 };

-- Map markers (client marker block 11046001): each points at the next
-- cutscene.
MARKERS = {
	[SEQ_000] = 11046001;
	[SEQ_015] = 11046002;
	[SEQ_020] = 11046003;
	[SEQ_035] = 11046004;
};

-- What the miners say between steps. The client script names no speaker;
-- the miners take the slots in the order they stand, the same in all
-- three Miner quests.
TALKS = {
	[SEQ_000] = {
		[ENPC_MOHTFRYD] = "processEvent000_2",
		[ENPC_PIERRIQUET] = "processEvent000_3",
		[ENPC_YUYUBESU] = "processEvent000_4",
		[ENPC_CHACHAI] = "processEvent000_5",
		[ENPC_FIFILO] = "processEvent000_6",
		[ENPC_MUMUKIYA] = "processEvent000_7",
		[ENPC_LINETTE] = "processEvent000_8",
	},
	[SEQ_035] = {
		[ENPC_ZSSAPA] = "processEvent035_3",
	},
	[SEQ_040] = {
		[ENPC_MOHTFRYD] = "processEvent040_2",
		[ENPC_PIERRIQUET] = "processEvent040_3",
		[ENPC_YUYUBESU] = "processEvent040_4",
		[ENPC_CHACHAI] = "processEvent040_5",
		[ENPC_FIFILO] = "processEvent040_6",
		[ENPC_MUMUKIYA] = "processEvent040_7",
	},
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_LINETTE, QFLAG_TALK);
		return;
	end
	if (TALKS[sequence] ~= nil) then
		for classId, _ in pairs(TALKS[sequence]) do
			quest:SetENpc(classId);
		end
	end
	if (sequence == SEQ_000 or sequence == SEQ_015) then
		quest:SetENpc(ENPC_ZSSAPA, QFLAG_TALK);
	elseif (sequence == SEQ_020 or sequence == SEQ_035) then
		quest:SetENpc(ENPC_NENEKKO, QFLAG_TALK);
	elseif (sequence == SEQ_040) then
		quest:SetENpc(ENPC_LINETTE, QFLAG_REWARD);
	end
end

local function warpTo(player, zone, spot)
	GetWorldManager():DoZoneChange(player, zone, nil, 0, 15, spot[1], spot[2], spot[3], spot[4]);
end

-- Z'ssapa looks at the first find in the bag she hasn't seen yet and
-- returns its flag. The shard stays with you (Nenekko asks for it later);
-- the others she keeps.
local function appraise(player, quest)
	local data = quest:GetData();
	local bag = player:GetItemPackage(INVENTORY_NORMAL);
	for _, find in ipairs(FINDS) do
		if (not data:GetFlag(find.flag) and bag:HasItem(find.item, 1)) then
			callClientFunction(player, "delegateEvent", player, quest, find.event);
			data:SetFlag(find.flag);
			if (find.item ~= ITEM_EWER_FRAGMENT) then
				bag:RemoveItem(find.item, 1);
			end
			return find.flag;
		end
	end
	return nil;
end

-- SetFlag only takes effect after the event, so the flag just set is
-- passed in.
local function allAppraised(quest, justSet)
	local data = quest:GetData();
	for _, find in ipairs(FINDS) do
		if (find.flag ~= justSet and not data:GetFlag(find.flag)) then
			return false;
		end
	end
	return true;
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_LINETTE) then
		-- Join the guild (1 = accepted at the quest card).
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventLinetteStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and npcClassId == ENPC_ZSSAPA) then
		-- min20010: the twins and their test.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		quest:StartSequence(SEQ_015);
	elseif (seq == SEQ_015 and npcClassId == ENPC_ZSSAPA) then
		local shown = appraise(player, quest);
		if (shown == nil) then
			-- Nothing new to show her: go and dig.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent015_1");
		elseif (allAppraised(quest, shown)) then
			-- min20020: everything you brought, and Nenekko knows the
			-- shard. It ends on an after-warp fade.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
			quest:StartSequence(SEQ_020);
			player:EndEvent();
			warpTo(player, MINES_ZONE, MINES_ENTRANCE);
			return;
		end
	elseif (seq == SEQ_020 and npcClassId == ENPC_NENEKKO) then
		-- min20030: Sil'dih, and the twins' sister. After-warp fade.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
		quest:StartSequence(SEQ_035);
		player:EndEvent();
		warpTo(player, MINES_ZONE, MINES_ENTRANCE);
		return;
	elseif (seq == SEQ_035 and npcClassId == ENPC_NENEKKO) then
		-- min20035: see her home; she keeps the shard. After-warp fade to
		-- the Concern.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent040");
		player:GetItemPackage(INVENTORY_NORMAL):RemoveItem(ITEM_EWER_FRAGMENT, 1);
		quest:StartSequence(SEQ_040);
		player:EndEvent();
		warpTo(player, CONCERN_ZONE, CONCERN);
		return;
	elseif (seq == SEQ_040 and npcClassId == ENPC_LINETTE) then
		-- Linette on the twins and Nenekko, and payment.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050");
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
	player:EndEvent();
end

function getJournalMapMarkerList(player, quest)
	return MARKERS[quest:GetSequence()];
end
