require ("global")
require ("quest")

--[[

Quest Script

Name:	She Walks in Beauty
Code:	Gld200
Id:	110360
Prereq: Level 20, Goldsmith

The Goldsmiths' Guild's welcome at Eshtaime's Lapidaries. Elecotte signs
you on and sends you to Colbernoux, who wants fresh materials: a miner at
the Nanawa Mines, Z'ssapa, parts with a bag of silver nuggets for his name
(gld20020). Colbernoux explains the custom of naming pieces after the
city's great ladies and sets you a brooch in Z'ssapa's likeness (gld20030).
The other goldsmiths send you to the miners for a muse: three women at
Amajina & Sons each sit for a sketch, and the three sketches make one
ideal one. Bring Colbernoux the brooch (gld20040: F'lhaminn comes in with
her broken brooch), look into F'lhaminn's past with the Echo (gld20050),
and Elecotte pays 20,000 gil and 2,000 experience.

Colbernoux and Z'ssapa only stood in instances in 1.23b; here they have
public spawns in the Lapidaries and at the mine entrance. The Echo is
played on F'lhaminn's stage spawn at the Concern. The brooch has no recipe
on this server yet, so it is checked in the bag as it would come out of a
synthesis.

Journal: steps 31-37 and 236 of the Ul'dah quest journal sheet (0B/45/08/4E).

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Speak with Colbernoux.
SEQ_010	= 10;  -- Ask Z'ssapa at the Nanawa Mines for materials.
SEQ_020	= 20;  -- Take the nuggets back to Colbernoux.
SEQ_030	= 30;  -- Find a muse among the miners.
SEQ_032	= 32;  -- Craft Z'ssapa's brooch and show it to Colbernoux.
SEQ_040	= 40;  -- Use the Echo on F'lhaminn.
SEQ_050	= 50;  -- See Elecotte about your reward.

-- Actor Class Ids
ENPC_ELECOTTE		= 1000950;
ENPC_COLBERNOUX		= 1000949;
ENPC_ZSSAPA			= 1000887;
ENPC_FLHAMINN		= 1000038;
-- Goldsmiths at the Lapidaries
ENPC_HAWAZI_ZOWAZI	= 1000638;
ENPC_ISABELLA		= 1000639;
ENPC_CICEROIX		= 1000640;
ENPC_LEFCHILD		= 1000994;
ENPC_SUNGI_KELUNGI	= 1001022;
ENPC_BOUCHARD		= 1001055;
ENPC_HOLBUBU		= 1001056;
-- The three miners who sit for a sketch
ENPC_CRHABYE		= 1001476;
ENPC_DIRIAINE		= 1001475;
ENPC_MAMAZA			= 1000652;

-- Quest items (journal itemData).
ITEM_SILVER_NUGGETS		= 11000121; -- Amajina silver nuggets (brooch material)
ITEM_ADORABLE_SKETCH	= 11000110;
ITEM_GRACEFUL_SKETCH	= 11000111;
ITEM_DASHING_SKETCH		= 11000112;
ITEM_IDEAL_SKETCH		= 11000113;
ITEM_ZSSAPA_BROOCH		= 11000108;

-- Each muse sets a flag once she has sat for her sketch.
MUSES = {
	[ENPC_CRHABYE] = { flag = 0, item = ITEM_ADORABLE_SKETCH, sit = "processEvent030_9", after = "processEvent032_2" },
	[ENPC_DIRIAINE] = { flag = 1, item = ITEM_GRACEFUL_SKETCH, sit = "processEvent030_10", after = "processEvent032_3" },
	[ENPC_MAMAZA] = { flag = 2, item = ITEM_DASHING_SKETCH, sit = "processEvent030_11", after = "processEvent032_4" },
};

REWARD_GIL	= 20000;
REWARD_EXP	= 2000;

-- In front of Colbernoux in the Lapidaries (gld20040 ends on an after-warp
-- fade).
GUILD_ZONE = 209;
COLBERNOUX_SPOT = { -122.5, 200.2, 262.5, -2.2 };

-- Map markers (client marker block 11036001): each points at the next
-- cutscene, gld200<n>0 = processEvent0<n>0.
MARKERS = {
	[SEQ_010] = 11036001;
	[SEQ_020] = 11036002;
	[SEQ_032] = 11036003;
	[SEQ_040] = 11036004;
};

-- What the guild says between steps. The client script names no speaker;
-- the goldsmiths take the slots in the order they stand, the same in all
-- three Goldsmith quests.
GOLDSMITH_CHATTER = {
	[ENPC_HAWAZI_ZOWAZI] = "processEvent007_2",
	[ENPC_ISABELLA] = "processEvent007_3",
	[ENPC_CICEROIX] = "processEvent007_4",
	[ENPC_LEFCHILD] = "processEvent007_5",
	[ENPC_SUNGI_KELUNGI] = "processEvent007_6",
	[ENPC_BOUCHARD] = "processEvent007_7",
};
TALKS = {
	[SEQ_000] = GOLDSMITH_CHATTER,
	[SEQ_010] = {
		[ENPC_COLBERNOUX] = "processEvent013_2",
		[ENPC_HAWAZI_ZOWAZI] = "processEvent007_2",
		[ENPC_ISABELLA] = "processEvent007_3",
		[ENPC_CICEROIX] = "processEvent007_4",
		[ENPC_LEFCHILD] = "processEvent007_5",
		[ENPC_SUNGI_KELUNGI] = "processEvent007_6",
		[ENPC_BOUCHARD] = "processEvent007_7",
	},
	[SEQ_020] = {
		[ENPC_ZSSAPA] = "processEvent020_2",
	},
	[SEQ_030] = {
		[ENPC_COLBERNOUX] = "processEvent030_2",
		[ENPC_HAWAZI_ZOWAZI] = "processEvent030_3",
		[ENPC_ISABELLA] = "processEvent030_4",
		[ENPC_CICEROIX] = "processEvent030_5",
		[ENPC_LEFCHILD] = "processEvent030_6",
		[ENPC_SUNGI_KELUNGI] = "processEvent030_7",
		[ENPC_BOUCHARD] = "processEvent030_8",
	},
	[SEQ_032] = {
		[ENPC_CRHABYE] = "processEvent032_2",
		[ENPC_DIRIAINE] = "processEvent032_3",
		[ENPC_MAMAZA] = "processEvent032_4",
		[ENPC_HAWAZI_ZOWAZI] = "processEvent030_3",
		[ENPC_ISABELLA] = "processEvent030_4",
	},
	[SEQ_040] = {
		[ENPC_COLBERNOUX] = "processEvent040_2",
		[ENPC_ELECOTTE] = "processEvent040_3",
		[ENPC_LEFCHILD] = "processEvent040_4",
	},
	[SEQ_050] = {
		[ENPC_COLBERNOUX] = "processEvent050_2",
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
	local data = quest:GetData();
	if (sequence == SEQ_000 or sequence == SEQ_020) then
		quest:SetENpc(ENPC_COLBERNOUX, QFLAG_TALK);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_ZSSAPA, QFLAG_TALK);
	elseif (sequence == SEQ_030) then
		for classId, muse in pairs(MUSES) do
			quest:SetENpc(classId, data:GetFlag(muse.flag) and QFLAG_OFF or QFLAG_TALK);
		end
	elseif (sequence == SEQ_032) then
		quest:SetENpc(ENPC_COLBERNOUX, QFLAG_REWARD);
	elseif (sequence == SEQ_040) then
		quest:SetENpc(ENPC_FLHAMINN, QFLAG_TALK);
	elseif (sequence == SEQ_050) then
		quest:SetENpc(ENPC_ELECOTTE, QFLAG_REWARD);
	end
end

local function hasItem(player, itemId)
	return player:GetItemPackage(INVENTORY_NORMAL):HasItem(itemId, 1);
end

-- SetFlag only takes effect after the event, so the flag just set is
-- passed in.
local function allSketched(data, justSet)
	for _, muse in pairs(MUSES) do
		if (muse.flag ~= justSet and not data:GetFlag(muse.flag)) then
			return false;
		end
	end
	return true;
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();
	local data = quest:GetData();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_ELECOTTE) then
		-- Join the guild (1 = accepted at the quest card).
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventElecotteStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and npcClassId == ENPC_COLBERNOUX) then
		-- Colbernoux's welcome, and the errand to Z'ssapa.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent013");
		quest:StartSequence(SEQ_010);
	elseif (seq == SEQ_010 and npcClassId == ENPC_ZSSAPA) then
		-- gld20020: Z'ssapa hears Colbernoux's name and hands over the
		-- nuggets for nothing.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		player:GetItemPackage(INVENTORY_NORMAL):AddItem(ITEM_SILVER_NUGGETS, 1, 1);
		quest:StartSequence(SEQ_020);
	elseif (seq == SEQ_020 and npcClassId == ENPC_COLBERNOUX) then
		-- gld20030: pieces named for ladies; make one for Z'ssapa.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
		quest:StartSequence(SEQ_030);
	elseif (seq == SEQ_030 and MUSES[npcClassId] ~= nil) then
		local muse = MUSES[npcClassId];
		if (data:GetFlag(muse.flag)) then
			callClientFunction(player, "delegateEvent", player, quest, muse.after);
		else
			-- She sits for a sketch.
			callClientFunction(player, "delegateEvent", player, quest, muse.sit);
			data:SetFlag(muse.flag);
			player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(muse.item, 1, 1);
			quest:SetENpc(npcClassId, QFLAG_OFF);
			if (allSketched(data, muse.flag)) then
				-- The three sketches make the ideal one.
				local keyItems = player:GetItemPackage(INVENTORY_KEYITEMS);
				keyItems:RemoveItem(ITEM_ADORABLE_SKETCH, 1);
				keyItems:RemoveItem(ITEM_GRACEFUL_SKETCH, 1);
				keyItems:RemoveItem(ITEM_DASHING_SKETCH, 1);
				keyItems:AddItem(ITEM_IDEAL_SKETCH, 1, 1);
				quest:StartSequence(SEQ_032);
			end
		end
	elseif (seq == SEQ_032 and npcClassId == ENPC_COLBERNOUX) then
		if (hasItem(player, ITEM_ZSSAPA_BROOCH)) then
			-- gld20040: the brooch, and F'lhaminn at the door. It ends on
			-- an after-warp fade.
			player:GetItemPackage(INVENTORY_NORMAL):RemoveItem(ITEM_ZSSAPA_BROOCH, 1);
			player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(ITEM_IDEAL_SKETCH, 1);
			callClientFunction(player, "delegateEvent", player, quest, "processEvent040");
			quest:StartSequence(SEQ_040);
			player:EndEvent();
			GetWorldManager():DoZoneChange(player, GUILD_ZONE, nil, 0, 15, COLBERNOUX_SPOT[1], COLBERNOUX_SPOT[2], COLBERNOUX_SPOT[3], COLBERNOUX_SPOT[4]);
			return;
		end
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030_2");
	elseif (seq == SEQ_040 and npcClassId == ENPC_FLHAMINN) then
		-- Her broken brooch, and the Echo (1 = look into her past).
		local echo = callClientFunction(player, "delegateEvent", player, quest, "processEvent045");
		if (echo == 1) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent050");
			quest:StartSequence(SEQ_050);
		end
	elseif (seq == SEQ_050 and npcClassId == ENPC_ELECOTTE) then
		-- Elecotte on Colbernoux and F'lhaminn, and payment.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent060");
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
