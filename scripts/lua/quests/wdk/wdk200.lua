require ("global")
require ("quest")

--[[

Quest Script

Name:	The Mouths of Babes
Code:	Wdk200
Id:	110300
Prereq: Level 20, Carpenter

A'naidjaa signs you on with the Carpenters' Guild and sends you out to
the Acorn Orchard to meet your first instructors: the Atrium's children
(wdk20010). They hand you a bundle of arrows for the Gods' Quiver at
Quarrymill. Wybir takes them (wdk20020) but her own bow is cracked: pick
one of three fallen branches near the hamlet and bring it to her. The
sturdy one is too stiff and the blooming one too thin; the supple one
mends the bow (processEvent025). Back at the orchard Marcelloix, the
children's real teacher, turns up late (wdk20030), and A'naidjaa pays
20,000 gil and 2,000 experience (processEvent040).

The orchard meeting is a push circle (1091100). Wybir ships stripped in
1.23b; the data gives her a class path and a spot at Quarrymill. The
branches are ??? objects (1091101-1091103). In the client the branch is
turned into a bow by a requested-items synthesis; the server has no such
recipe, so the branch itself stands for the bow when you hand it over.

Journal: rows 65-69 of the quest journal sheet. Map markers: see MARKERS.

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Meet your instructors in the Acorn Orchard.
SEQ_010	= 10;  -- Take the children's arrows to Quarrymill.
SEQ_020	= 20;  -- Find wood to mend Wybir's bow.
SEQ_025	= 25;  -- Report to the children.
SEQ_030	= 30;  -- A'naidjaa has your reward.

-- Actor Class Ids
ENPC_ANAIDJAA		= 1000465;
ENPC_HABREHAM		= 1000621;
ENPC_DECIMA			= 1000622;
ENPC_CHALYO_TAMLYO	= 1000623;
ENPC_CAPLAN			= 1000822;
ENPC_ULMHYLT		= 1000823;
ENPC_NICOLIAUX		= 1000409;
ENPC_WYBIR			= 1000556;
ENPC_ORCHARD		= 1091100; -- push circle in the Acorn Orchard
ENPC_STURDY_BRANCH	= 1091101; -- ??? at Quarrymill
ENPC_SUPPLE_BRANCH	= 1091102;
ENPC_BLOOMING_BRANCH = 1091103;

-- Key items
ITEM_ATRIUM_ARROW		= 11000067;
ITEM_BLOOMING_BRANCH	= 11000062;
ITEM_SUPPLE_BRANCH		= 11000063;
ITEM_STURDY_BRANCH		= 11000064;

REWARD_GIL	= 20000;
REWARD_EXP	= 2000;

-- Where the after-warp scenes leave you.
ORCHARD_SPOT = { 206, -36.0, 8.0, -1256.0, 0.0 };
WYBIR_SPOT = { 154, 1443.0, -13.32, 878.0, -0.7 };

-- The branches: the client's look and ask handlers, the key item, and
-- what Wybir says when it comes back as a bow (nil: the right one).
BRANCHES = {
	[ENPC_STURDY_BRANCH] = { look = "processEvent020_3_2", ask = "processEvent020_3", item = ITEM_STURDY_BRANCH, verdict = "processEvent020_6" },
	[ENPC_SUPPLE_BRANCH] = { look = "processEvent020_4_2", ask = "processEvent020_4", item = ITEM_SUPPLE_BRANCH },
	[ENPC_BLOOMING_BRANCH] = { look = "processEvent020_5_2", ask = "processEvent020_5", item = ITEM_BLOOMING_BRANCH, verdict = "processEvent020_7" },
};

-- Guild chatter. The client names no speakers; the guild members are
-- picked by the lines' content.
TALKS = {
	[SEQ_000] = {
		[ENPC_ANAIDJAA] = "processEvent005_2",
		[ENPC_DECIMA] = "processEvent005_3",
		[ENPC_CAPLAN] = "processEvent005_4",
		[ENPC_ULMHYLT] = "processEvent005_5",
		[ENPC_CHALYO_TAMLYO] = "processEvent005_6",
		[ENPC_HABREHAM] = "processEvent005_7",
	},
	[SEQ_010] = {
		[ENPC_ANAIDJAA] = "processEvent010_2",
		[ENPC_NICOLIAUX] = "processEvent010_3",
	},
	[SEQ_020] = {
		[ENPC_ANAIDJAA] = "processEvent010_2",
	},
	[SEQ_025] = {
		[ENPC_ANAIDJAA] = "processEvent025_2",
		[ENPC_WYBIR] = "processEvent025_3",
	},
	[SEQ_030] = {
		[ENPC_DECIMA] = "processEvent030_2",
		[ENPC_CAPLAN] = "processEvent030_3",
		[ENPC_ULMHYLT] = "processEvent030_4",
		[ENPC_CHALYO_TAMLYO] = "processEvent030_5",
		[ENPC_HABREHAM] = "processEvent030_6",
		[ENPC_NICOLIAUX] = "processEvent030_7",
	},
};

-- Map markers (client marker block 11030001): each points at the next
-- cutscene, wdk200<n>0 = processEvent0<n>0; steps between scenes have none.
MARKERS = {
	[SEQ_000] = 11030001;
	[SEQ_010] = 11030002;
	[SEQ_020] = 11030002;
	[SEQ_025] = 11030003;
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_ANAIDJAA, QFLAG_TALK);
		return;
	end
	if (TALKS[sequence] ~= nil) then
		for classId, _ in pairs(TALKS[sequence]) do
			quest:SetENpc(classId);
		end
	end
	if (sequence == SEQ_000 or sequence == SEQ_025) then
		quest:SetENpc(ENPC_ORCHARD, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_WYBIR, QFLAG_TALK);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(ENPC_WYBIR, QFLAG_TALK);
		for classId, _ in pairs(BRANCHES) do
			quest:SetENpc(classId, QFLAG_TALK);
		end
	elseif (sequence == SEQ_030) then
		quest:SetENpc(ENPC_ANAIDJAA, QFLAG_REWARD);
	end
end

local function warpTo(player, spot)
	GetWorldManager():DoZoneChange(player, spot[1], nil, 0, 15, spot[2], spot[3], spot[4], spot[5]);
end

local function heldBranch(player)
	local bag = player:GetItemPackage(INVENTORY_KEYITEMS);
	for classId, branch in pairs(BRANCHES) do
		if (bag:HasItem(branch.item)) then
			return classId, branch;
		end
	end
	return nil, nil;
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();
	local keyItems = player:GetItemPackage(INVENTORY_KEYITEMS);

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_ANAIDJAA) then
		-- Join the guild, then the first task (1 = accepted).
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventANaidjaaStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_010 and npcClassId == ENPC_WYBIR) then
		-- wdk20020: the arrows delivered, and the cracked bow. It ends on an
		-- after-warp fade.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		keyItems:RemoveItem(ITEM_ATRIUM_ARROW, 1);
		quest:StartSequence(SEQ_020);
		player:EndEvent();
		warpTo(player, WYBIR_SPOT);
		return;
	elseif (seq == SEQ_020 and BRANCHES[npcClassId] ~= nil) then
		-- Look at the branch, then take it or leave it. Only one at a time.
		local branch = BRANCHES[npcClassId];
		callClientFunction(player, "delegateEvent", player, quest, branch.look);
		local take = callClientFunction(player, "delegateEvent", player, quest, branch.ask);
		if (take == 1 and not keyItems:HasItem(branch.item)) then
			local _, held = heldBranch(player);
			if (held ~= nil) then
				keyItems:RemoveItem(held.item, 1);
			end
			keyItems:AddItem(branch.item, 1, 1);
		end
	elseif (seq == SEQ_020 and npcClassId == ENPC_WYBIR) then
		local _, branch = heldBranch(player);
		if (branch == nil) then
			-- Where to look for timber.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020_2");
		elseif (branch.verdict ~= nil) then
			-- Too stiff, or too thin: try another branch.
			callClientFunction(player, "delegateEvent", player, quest, branch.verdict);
			keyItems:RemoveItem(branch.item, 1);
		else
			-- The supple branch: the bow is mended. It ends on an after-warp
			-- fade.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent025");
			keyItems:RemoveItem(branch.item, 1);
			quest:StartSequence(SEQ_025);
			player:EndEvent();
			warpTo(player, WYBIR_SPOT);
			return;
		end
	elseif (seq == SEQ_030 and npcClassId == ENPC_ANAIDJAA) then
		-- A'naidjaa knew all along; the guild's gift, and payment.
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

	if (npcClassId == ENPC_ORCHARD and seq == SEQ_000) then
		-- wdk20010: the children, and their arrows for the Gods' Quiver. It
		-- ends on an after-warp fade.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(ITEM_ATRIUM_ARROW, 1, 1);
		quest:StartSequence(SEQ_010);
		player:EndEvent();
		warpTo(player, ORCHARD_SPOT);
		return;
	elseif (npcClassId == ENPC_ORCHARD and seq == SEQ_025) then
		-- wdk20030: the report, and Marcelloix, late.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
		quest:StartSequence(SEQ_030);
	end
	player:EndEvent();
end

function getJournalMapMarkerList(player, quest)
	return MARKERS[quest:GetSequence()];
end
