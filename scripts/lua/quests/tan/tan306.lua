require ("global")
require ("quest")

--[[

Quest Script

Name:	Head of the Class
Code:	Tan306
Id:	110382
Prereq: Level 36, Leatherworker, Tan300

Hereward calls Lalatta's pupils together at Atelier Fen-Yll. Lalatta
arrives and sets the evaluation: mend the goods left for the moogles at
Lifemend Stump (tan30610). At the stump the goods are gone (tan30620):
another pupil took the lot. Back at the guild he denies wrongdoing
(processEvent023) but, talked round, gives up a pair of damaged Fen-Yll
boots (processEvent025). Maddeline tells you how to mend them with boar
leather; Hereward is looking them over when a pupil brings in a part of
an imperial juggernaut and Lalatta orders everyone back (tan30630). The
Echo on Lalatta shows how she once did the same (processEvent040,
tan30640), and Hereward hears the pupils' evaluations of her and pays
36,000 gil and 3,600 experience (tan30650).

The other pupils ship stripped in 1.23b, so the meeting in the guild is a
push circle (1091112), as is the stump (1091111). Lalatta stands in the
guild for the Echo (the data gives her second body 1000467 a class path
and a spot). In the client the boots are mended by a requested-items
synthesis and Maddeline first sets a practice synthesis of five pieces;
the server has no such recipes yet, so the practice is skipped but
Maddeline still checks for the mended boots.

Journal: rows 108-114, 191 and 196 of the quest journal sheet. Map markers: see MARKERS.

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Wait with Lalatta's pupils at Atelier Fen-Yll.
SEQ_010	= 10;  -- Go to Lifemend Stump.
SEQ_020	= 20;  -- Find out who took the goods.
SEQ_027	= 27;  -- Mend the boots.
SEQ_028	= 28;  -- Show the boots to Hereward.
SEQ_030	= 30;  -- Use the Echo on Lalatta.
SEQ_040	= 40;  -- Speak with Hereward.

-- Actor Class Ids
ENPC_HEREWARD		= 1000231;
ENPC_ALIXE			= 1000066;
ENPC_DADALO			= 1000067;
ENPC_KAIN			= 1000068;
ENPC_BELI			= 1001077;
ENPC_MADDELINE		= 1001078;
ENPC_LUILDA			= 1001082;
ENPC_LALATTA		= 1000467; -- in Atelier Fen-Yll
ENPC_GATHERING		= 1091112; -- push circle where the pupils gather
ENPC_LIFEMEND_STUMP	= 1091111; -- push circle at Lifemend Stump

-- Items
ITEM_DAMAGED_BOOTS	= 11000048; -- key item
ITEM_VINTAGE_BOOTS	= 11000049; -- crafted, normal bag

REWARD_GIL	= 36000;
REWARD_EXP	= 3600;

GUILD_SPOT = { 206, 95.0, 20.0, -1466.0, -0.5 };

-- Guild chatter, speakers picked by the lines' content.
TALKS = {
	[SEQ_000] = {
		[ENPC_HEREWARD] = "processEvent005_2",
		[ENPC_BELI] = "processEvent005_3",
		[ENPC_MADDELINE] = "processEvent005_4",
		[ENPC_DADALO] = "processEvent005_5",
		[ENPC_KAIN] = "processEvent005_6",
	},
	[SEQ_010] = {
		[ENPC_HEREWARD] = "processEvent010_2",
		[ENPC_BELI] = "processEvent010_3",
		[ENPC_MADDELINE] = "processEvent010_4",
		[ENPC_LUILDA] = "processEvent010_5",
		[ENPC_DADALO] = "processEvent010_6",
		[ENPC_ALIXE] = "processEvent010_7",
		[ENPC_KAIN] = "processEvent010_8",
	},
	[SEQ_020] = {
		[ENPC_HEREWARD] = "processEvent020_2",
		[ENPC_BELI] = "processEvent020_3",
		[ENPC_MADDELINE] = "processEvent020_4",
		[ENPC_LUILDA] = "processEvent020_5",
		[ENPC_DADALO] = "processEvent020_6",
	},
	[SEQ_027] = {
		[ENPC_HEREWARD] = "processEvent027_2",
		[ENPC_BELI] = "processEvent027_5",
		[ENPC_DADALO] = "processEvent027_6",
		[ENPC_LUILDA] = "processEvent027_7",
		[ENPC_ALIXE] = "processEvent027_8",
	},
	[SEQ_028] = { [ENPC_MADDELINE] = "processEvent028" },
	[SEQ_030] = {
		[ENPC_BELI] = "processEvent030_3",
		[ENPC_MADDELINE] = "processEvent030_4",
		[ENPC_DADALO] = "processEvent030_5",
	},
	[SEQ_040] = {
		[ENPC_BELI] = "processEvent040_3",
		[ENPC_MADDELINE] = "processEvent040_4",
		[ENPC_LUILDA] = "processEvent040_5",
		[ENPC_DADALO] = "processEvent040_6",
		[ENPC_ALIXE] = "processEvent040_7",
		[ENPC_KAIN] = "processEvent040_8",
	},
};

-- Map markers (client marker block 11038201): each points at the next
-- cutscene, tan306<n>0 = processEvent0<n>0; steps between scenes have none.
MARKERS = {
	[SEQ_000] = 11038201;
	[SEQ_010] = 11038202;
	[SEQ_028] = 11038203;
	[SEQ_030] = 11038204;
	[SEQ_040] = 11038205;
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
		quest:SetENpc(ENPC_GATHERING, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_LIFEMEND_STUMP, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_027) then
		quest:SetENpc(ENPC_MADDELINE, QFLAG_TALK);
	elseif (sequence == SEQ_028) then
		quest:SetENpc(ENPC_HEREWARD, QFLAG_TALK);
	elseif (sequence == SEQ_030) then
		quest:SetENpc(ENPC_LALATTA, QFLAG_TALK);
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
	local bag = player:GetItemPackage(INVENTORY_NORMAL);
	local keyItems = player:GetItemPackage(INVENTORY_KEYITEMS);

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_HEREWARD) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventHerewardStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (npcClassId == ENPC_MADDELINE and seq == SEQ_027) then
		if (bag:HasItem(ITEM_VINTAGE_BOOTS)) then
			-- The boots mended; they are to go to Hereward.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent027_10");
			if (keyItems:HasItem(ITEM_DAMAGED_BOOTS)) then
				keyItems:RemoveItem(ITEM_DAMAGED_BOOTS, 1);
			end
			callClientFunction(player, "delegateEvent", player, quest, "processEvent028");
			quest:StartSequence(SEQ_028);
		else
			-- What the boots will need.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent027_4", ITEM_DAMAGED_BOOTS, 1);
		end
	elseif (npcClassId == ENPC_HEREWARD and seq == SEQ_028) then
		-- tan30630: the appraisal, and the juggernaut part. It ends on an
		-- after-warp fade.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
		bag:RemoveItem(ITEM_VINTAGE_BOOTS, 1);
		quest:StartSequence(SEQ_030);
		player:EndEvent();
		warpTo(player, GUILD_SPOT);
		return;
	elseif (npcClassId == ENPC_LALATTA and seq == SEQ_030) then
		-- Lalatta's verdict and the Echo prompt; 1 plays tan30640, which
		-- ends on an after-warp fade.
		local seen = callClientFunction(player, "delegateEvent", player, quest, "processEvent040");
		if (seen == 1) then
			quest:StartSequence(SEQ_040);
			player:EndEvent();
			warpTo(player, GUILD_SPOT);
			return;
		end
	elseif (npcClassId == ENPC_HEREWARD and seq == SEQ_040) then
		-- tan30650: the pupils' word on Lalatta, and payment.
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

	if (npcClassId == ENPC_GATHERING and seq == SEQ_000) then
		-- tan30610: Lalatta sets the evaluation. It ends on an after-warp
		-- fade.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		quest:StartSequence(SEQ_010);
		player:EndEvent();
		warpTo(player, GUILD_SPOT);
		return;
	elseif (npcClassId == ENPC_LIFEMEND_STUMP and seq == SEQ_010) then
		-- tan30620: the goods are gone.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		quest:StartSequence(SEQ_020);
	elseif (npcClassId == ENPC_GATHERING and seq == SEQ_020) then
		-- The pupil who took everything; talked round, he gives up a pair
		-- of boots.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent023");
		callClientFunction(player, "delegateEvent", player, quest, "processEvent025");
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(ITEM_DAMAGED_BOOTS, 1, 1);
		quest:StartSequence(SEQ_027);
	end
	player:EndEvent();
end

function getJournalMapMarkerList(player, quest)
	return MARKERS[quest:GetSequence()];
end
