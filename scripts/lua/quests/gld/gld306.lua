require ("global")
require ("quest")

--[[

Quest Script

Name:	Struck Through the Heart
Code:	Gld306
Id:	110362
Prereq: Level 36, Goldsmith, Gld300

Someone tried to steal Heartstrike, the famed dagger Lord Lolorito keeps,
and the guild means to hide it among copies (gld30610). Sence keeps the
storerooms: win her leave and she hands over the materials (pure metal
ore, brilliant glass shards, silverwater). Bring Elecotte a Heartstrike
replica; Colbernoux comes back and tells the blade's story (gld30615), and
asks you to meet him in Erralig's Burial Chamber in Arrzaneth Ossuary.
There he shows you his brother's unchanged body (gld30620); the Echo
shows his meeting with Greinfarr (gld30630). Back at the Lapidaries,
Colbernoux pays 36,000 gil and 3,600 experience.

The storeroom was an instance in 1.23b: Sence has a public spawn by the
Lapidaries' back door, her parley is left out and the three material
spots are folded into her second talk. The burial chamber is a push circle
by the Ossuary; Colbernoux only appears there in the scenes, so the circle
also offers the Echo. The replica has no recipe on this server yet, so it
is checked in the bag as it would come out of a synthesis.

Journal: steps 169-173 of the Ul'dah quest journal sheet (0B/45/08/4E).

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Get Sence's leave to enter the storerooms.
SEQ_010	= 10;  -- Bring the materials back to Sence.
SEQ_015	= 15;  -- Craft a Heartstrike replica for Elecotte.
SEQ_020	= 20;  -- Meet Colbernoux in Erralig's Burial Chamber.
SEQ_025	= 25;  -- Use the Echo on Colbernoux.
SEQ_040	= 40;  -- Return to Eshtaime's Lapidaries.

-- Actor Class Ids
ENPC_ELECOTTE		= 1000950;
ENPC_COLBERNOUX		= 1000949;
ENPC_SENCE			= 1001498;
ENPC_CHAMBER_CIRCLE	= 1091181; -- Erralig's Burial Chamber door
-- Goldsmiths at the Lapidaries
ENPC_HAWAZI_ZOWAZI	= 1000638;
ENPC_ISABELLA		= 1000639;
ENPC_CICEROIX		= 1000640;
ENPC_LEFCHILD		= 1000994;
ENPC_SUNGI_KELUNGI	= 1001022;
ENPC_BOUCHARD		= 1001055;

-- Storeroom materials (synthesis materials, normal bag) and the replica.
ITEM_PURE_METAL_ORE		= 11000117;
ITEM_GLASS_SHARDS		= 11000118;
ITEM_SILVERWATER		= 11000119;
ITEM_HEARTSTRIKE_REPLICA	= 11000116;

REWARD_GIL	= 36000;
REWARD_EXP	= 3600;

-- gld30630 ends on an after-warp fade, back in the Lapidaries in front of
-- Colbernoux.
GUILD_ZONE = 209;
COLBERNOUX_SPOT = { -122.5, 200.2, 262.5, -2.2 };

-- Map markers (client marker block 11036201): each points at the next
-- cutscene.
MARKERS = {
	[SEQ_015] = 11036202;
	[SEQ_020] = 11036203;
	[SEQ_025] = 11036204;
};

-- What the guild says between steps. The client script names no speaker;
-- the goldsmiths keep the same slots as in Gld200.
STOREROOM_CHATTER = {
	[ENPC_ELECOTTE] = "processEvent010_2",
	[ENPC_HAWAZI_ZOWAZI] = "processEvent010_3",
	[ENPC_ISABELLA] = "processEvent010_4",
	[ENPC_CICEROIX] = "processEvent010_5",
	[ENPC_LEFCHILD] = "processEvent010_6",
	[ENPC_SUNGI_KELUNGI] = "processEvent010_7",
};
TALKS = {
	[SEQ_000] = STOREROOM_CHATTER,
	[SEQ_010] = STOREROOM_CHATTER,
	[SEQ_015] = {
		[ENPC_SENCE] = "processEvent013_2",
		[ENPC_HAWAZI_ZOWAZI] = "processEvent010_3",
		[ENPC_ISABELLA] = "processEvent010_4",
		[ENPC_CICEROIX] = "processEvent010_5",
		[ENPC_LEFCHILD] = "processEvent010_6",
		[ENPC_SUNGI_KELUNGI] = "processEvent010_7",
	},
	[SEQ_020] = {
		[ENPC_BOUCHARD] = "processEvent015_2",
	},
	[SEQ_025] = {
		[ENPC_BOUCHARD] = "processEvent015_2",
	},
	[SEQ_040] = {
		[ENPC_HAWAZI_ZOWAZI] = "processEvent030_2",
		[ENPC_ISABELLA] = "processEvent030_3",
		[ENPC_CICEROIX] = "processEvent030_4",
		[ENPC_LEFCHILD] = "processEvent030_5",
		[ENPC_SUNGI_KELUNGI] = "processEvent030_6",
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
	if (sequence == SEQ_000 or sequence == SEQ_010) then
		quest:SetENpc(ENPC_SENCE, QFLAG_TALK);
	elseif (sequence == SEQ_015) then
		quest:SetENpc(ENPC_ELECOTTE, QFLAG_REWARD);
	elseif (sequence == SEQ_020 or sequence == SEQ_025) then
		quest:SetENpc(ENPC_CHAMBER_CIRCLE, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_040) then
		quest:SetENpc(ENPC_COLBERNOUX, QFLAG_REWARD);
	end
end

local function warpTo(player, zone, spot)
	GetWorldManager():DoZoneChange(player, zone, nil, 0, 15, spot[1], spot[2], spot[3], spot[4]);
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();
	local bag = player:GetItemPackage(INVENTORY_NORMAL);

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_ELECOTTE) then
		-- gld30610: Lord Lolorito's task (1 = accepted).
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventElecotteStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and npcClassId == ENPC_SENCE) then
		-- Sence wants proof you can be trusted, then gives her leave and
		-- a bag (her parley is left out).
		callClientFunction(player, "delegateEvent", player, quest, "processEvent011");
		callClientFunction(player, "delegateEvent", player, quest, "processEvent012");
		quest:StartSequence(SEQ_010);
	elseif (seq == SEQ_010 and npcClassId == ENPC_SENCE) then
		-- She checks the bag and lets you take the materials.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent012_5");
		bag:AddItem(ITEM_PURE_METAL_ORE, 1, 1);
		bag:AddItem(ITEM_GLASS_SHARDS, 1, 1);
		bag:AddItem(ITEM_SILVERWATER, 1, 1);
		quest:StartSequence(SEQ_015);
	elseif (seq == SEQ_015 and npcClassId == ENPC_ELECOTTE) then
		if (bag:HasItem(ITEM_HEARTSTRIKE_REPLICA, 1)) then
			-- gld30615: the replica, and Colbernoux's return.
			bag:RemoveItem(ITEM_HEARTSTRIKE_REPLICA, 1);
			callClientFunction(player, "delegateEvent", player, quest, "processEvent015");
			quest:StartSequence(SEQ_020);
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010_2");
		end
	elseif (seq == SEQ_040 and npcClassId == ENPC_COLBERNOUX) then
		-- Payment, and Colbernoux asks to be alone.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent040");
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

-- Colbernoux by his brother's body: the Echo (1 = look into his past),
-- then gld30630 with its after-warp fade back to the Lapidaries.
local function offerEcho(player, quest)
	local echo = callClientFunction(player, "delegateEvent", player, quest, "processEvent025");
	if (echo == 1) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
		quest:StartSequence(SEQ_040);
		player:EndEvent();
		warpTo(player, GUILD_ZONE, COLBERNOUX_SPOT);
		return true;
	end
	return false;
end

function onPush(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (npcClassId == ENPC_CHAMBER_CIRCLE and seq == SEQ_020) then
		-- gld30620: Niellefresne's body and Heartstrike's power.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		quest:StartSequence(SEQ_025);
		if (offerEcho(player, quest)) then
			return;
		end
	elseif (npcClassId == ENPC_CHAMBER_CIRCLE and seq == SEQ_025) then
		if (offerEcho(player, quest)) then
			return;
		end
	end
	player:EndEvent();
end

function getJournalMapMarkerList(player, quest)
	return MARKERS[quest:GetSequence()];
end
