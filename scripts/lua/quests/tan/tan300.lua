require ("global")
require ("quest")

--[[

Quest Script

Name:	Design Imposters
Code:	Tan300
Id:	110381
Prereq: Level 30, Leatherworker, Tan200

Bandits on the north roads keep taking Fen-Yll goods, so Hereward sends
pieces north one at a time: you carry a leather chocobo saddle to Owl's
Nest. Near the hamlet a bandit jumps you and Lalatta knocks him out
(tan30010). Ser Yuhelmeric takes the saddle (tan30020). Back on the road
Lalatta's call comes: make a Fen-Yll birkin bag and bring it to Clearwater
Lake (processEvent025). There the bandits hold Lalatta and another
leatherworker and doubt your bag (tan30030); talk them round, and the
Knights of Ishgard ride the bandits down (tan30040). Hereward and Lalatta
settle up: 30,000 gil and 3,000 experience (tan30050).

The road near Owl's Nest and the lakeshore are push circles (1091109,
1091110): the bandits and Lalatta here are cutscene-only. In the client
the bag is a requested-items synthesis; the server has no such recipe
yet, but the lake still checks for the bag and the knights' scene takes
it. The parley with the bandit leader is reduced to stepping back
into the circle.

Journal: rows 102-107 of the quest journal sheet. Map markers: see MARKERS.

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Take the saddle to Owl's Nest.
SEQ_010	= 10;  -- Deliver it to the Knights of Ishgard.
SEQ_020	= 20;  -- Look for Lalatta on the road.
SEQ_025	= 25;  -- Make a birkin bag and take it to Clearwater Lake.
SEQ_030	= 30;  -- Parley with the bandits.
SEQ_040	= 40;  -- Report to Hereward.

-- Actor Class Ids
ENPC_HEREWARD		= 1000231;
ENPC_ALIXE			= 1000066;
ENPC_DADALO			= 1000067;
ENPC_KAIN			= 1000068;
ENPC_BELI			= 1001077;
ENPC_MADDELINE		= 1001078;
ENPC_LUILDA			= 1001082;
ENPC_YUHELMERIC		= 1000370;
ENPC_ROAD			= 1091109; -- push circle on the road below Owl's Nest
ENPC_CLEARWATER		= 1091110; -- push circle on the shore of Clearwater Lake

-- Items
ITEM_CHOCOBO_SADDLE	= 11000021; -- key items
ITEM_BIRKIN_BAG		= 11000047; -- crafted, normal bag

REWARD_GIL	= 30000;
REWARD_EXP	= 3000;

-- The after-warp landings at the lake: just outside the circle, so the
-- next step means stepping back in.
LAKESHORE_SPOT = { 145, 2160.0, 142.6, 622.0, 0.8 };

-- Guild chatter, speakers picked by the lines' content.
TALKS = {
	[SEQ_000] = {
		[ENPC_HEREWARD] = "processEvent005_2",
		[ENPC_BELI] = "processEvent005_3",
		[ENPC_MADDELINE] = "processEvent005_4",
		[ENPC_LUILDA] = "processEvent005_5",
		[ENPC_DADALO] = "processEvent005_6",
		[ENPC_ALIXE] = "processEvent005_7",
		[ENPC_KAIN] = "processEvent005_8",
	},
	[SEQ_010] = { [ENPC_HEREWARD] = "processEvent005_2" },
	[SEQ_020] = { [ENPC_HEREWARD] = "processEvent020_2" },
	[SEQ_025] = {
		[ENPC_HEREWARD] = "processEvent025_2",
		[ENPC_BELI] = "processEvent025_3",
		[ENPC_MADDELINE] = "processEvent025_4",
		[ENPC_LUILDA] = "processEvent025_5",
		[ENPC_DADALO] = "processEvent025_6",
		[ENPC_ALIXE] = "processEvent025_7",
		[ENPC_KAIN] = "processEvent025_8",
	},
	[SEQ_040] = {
		[ENPC_BELI] = "processEvent040_2",
		[ENPC_MADDELINE] = "processEvent040_3",
		[ENPC_LUILDA] = "processEvent040_4",
		[ENPC_DADALO] = "processEvent040_5",
		[ENPC_ALIXE] = "processEvent040_6",
		[ENPC_KAIN] = "processEvent040_7",
	},
};

-- Map markers (client marker block 11038101): each points at the next
-- cutscene, tan300<n>0 = processEvent0<n>0; steps between scenes have none.
MARKERS = {
	[SEQ_000] = 11038101;
	[SEQ_010] = 11038102;
	[SEQ_025] = 11038103;
	[SEQ_030] = 11038104;
	[SEQ_040] = 11038105;
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_HEREWARD, QFLAG_TALK);
		return;
	end
	if (TALKS[sequence] ~= nil) then
		for classId, _ in pairs(TALKS[sequence]) do
			quest:SetENpc(classId);
		end
	end
	if (sequence == SEQ_000 or sequence == SEQ_020) then
		quest:SetENpc(ENPC_ROAD, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_YUHELMERIC, QFLAG_TALK);
	elseif (sequence == SEQ_025 or sequence == SEQ_030) then
		quest:SetENpc(ENPC_CLEARWATER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_040) then
		quest:SetENpc(ENPC_HEREWARD, QFLAG_REWARD);
	end
end

local function warpTo(player, spot)
	GetWorldManager():DoZoneChange(player, spot[1], nil, 0, 15, spot[2], spot[3], spot[4], spot[5]);
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_HEREWARD) then
		-- Help with the plan? Accepting hands you the saddle.
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventHerewardStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
			player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(ITEM_CHOCOBO_SADDLE, 1, 1);
		end
		player:EndEvent();
		return;
	elseif (npcClassId == ENPC_YUHELMERIC and seq == SEQ_010) then
		-- tan30020: the knights take the saddle.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(ITEM_CHOCOBO_SADDLE, 1);
		quest:StartSequence(SEQ_020);
	elseif (npcClassId == ENPC_HEREWARD and seq == SEQ_040) then
		-- tan30050: Hereward and Lalatta, and payment.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050");
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
	local bag = player:GetItemPackage(INVENTORY_NORMAL);

	if (npcClassId == ENPC_ROAD and seq == SEQ_000) then
		-- tan30010: the bandit, and Lalatta.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		quest:StartSequence(SEQ_010);
	elseif (npcClassId == ENPC_ROAD and seq == SEQ_020) then
		-- Lalatta's call: a birkin bag, at Clearwater Lake.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent025");
		quest:StartSequence(SEQ_025);
	elseif (npcClassId == ENPC_CLEARWATER and seq == SEQ_025) then
		if (bag:HasItem(ITEM_BIRKIN_BAG)) then
			-- The bag brought; tan30030: the bandits doubt it. It ends on an
			-- after-warp fade.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
			quest:StartSequence(SEQ_030);
			player:EndEvent();
			warpTo(player, LAKESHORE_SPOT);
			return;
		end
		-- No bag yet: nothing happens at the lake (the client has no line).
	elseif (npcClassId == ENPC_CLEARWATER and seq == SEQ_030) then
		-- tan30040: the knights ride in. It ends on an after-warp fade.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent040");
		if (bag:HasItem(ITEM_BIRKIN_BAG)) then
			bag:RemoveItem(ITEM_BIRKIN_BAG, 1);
		end
		quest:StartSequence(SEQ_040);
		player:EndEvent();
		warpTo(player, LAKESHORE_SPOT);
		return;
	end
	player:EndEvent();
end

function getJournalMapMarkerList(player, quest)
	return MARKERS[quest:GetSequence()];
end
