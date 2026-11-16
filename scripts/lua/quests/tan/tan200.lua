require ("global")
require ("quest")

--[[

Quest Script

Name:	The Silent Partners
Code:	Tan200
Id:	110380
Prereq: Level 20, Leatherworker

Hereward takes you on at Atelier Fen-Yll and sends you to your mentor
Lalatta at the Ebony Stalls, where the Wood Wailers are leaving in a huff
over her slow repairs (tan20010). She hands you their damaged armor to
mend with aldgoat leather (tan20020); when you bring it back her own
attempt has come to nothing and she runs off in tears, leaving the
remnants (tan20030). Hereward wants the armor made anew from the remnants
and more of the same leather (processEvent033); he looks it over, has you
wear it to the chocobo stables and back, and passes it (processEvent037).
Gylbart of the Wood Wailers takes it at Quarrymill (tan20040), and back
at the guild Lalatta vouches for you and Hereward pays 20,000 gil and
2,000 experience (tan20050).

Lalatta and Gylbart ship stripped in 1.23b; the data gives them class
paths and spots (Lalatta at the Ebony Stalls, Gylbart at Quarrymill). The
walk to the stables is a push circle (1091108). In the client both
repairs are requested-items syntheses that make the repaired armor; here
they are quest recipes (questrecipes/tan.lua).

Journal: rows 5-12 and 190 of the quest journal sheet. Map markers: see MARKERS.

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Find Lalatta at the Ebony Stalls.
SEQ_010	= 10;  -- Speak with Lalatta.
SEQ_020	= 20;  -- Repair the Wood Wailers' armor.
SEQ_030	= 30;  -- Ask at Atelier Fen-Yll.
SEQ_033	= 33;  -- Craft the armor anew.
SEQ_035	= 35;  -- Wear it to the chocobo stables and back.
SEQ_037	= 37;  -- Deliver the armor to Quarrymill.
SEQ_040	= 40;  -- Report to Hereward.

-- Actor Class Ids
ENPC_HEREWARD		= 1000231;
ENPC_ALIXE			= 1000066;
ENPC_DADALO			= 1000067;
ENPC_KAIN			= 1000068;
ENPC_BELI			= 1001077;
ENPC_MADDELINE		= 1001078;
ENPC_DYRSTBROD		= 1001079;
ENPC_LUILDA			= 1001082;
ENPC_LALATTA		= 1000368; -- at the Ebony Stalls
ENPC_GYLBART		= 1000978; -- at Quarrymill
ENPC_STABLES		= 1091108; -- push circle at the chocobo stables

-- Items
-- Normal bag: the quest recipes' materials and result.
ITEM_DAMAGED_ARMOR	= 11000044;
ITEM_ARMOR_REMNANTS	= 11000046;
ITEM_REPAIRED_ARMOR	= 11000045;

-- Quest Flags
FLAG_WALKED	= 0;	-- wore the armor to the stables

REWARD_GIL	= 20000;
REWARD_EXP	= 2000;

LALATTA_SPOT = { 206, 187.5, 27.7, -1394.5, -1.8 };

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
	[SEQ_020] = {
		[ENPC_HEREWARD] = "processEvent020_2",
		[ENPC_BELI] = "processEvent020_3",
		[ENPC_MADDELINE] = "processEvent020_4",
		[ENPC_LUILDA] = "processEvent020_5",
		[ENPC_DADALO] = "processEvent020_6",
		[ENPC_ALIXE] = "processEvent020_7",
		[ENPC_KAIN] = "processEvent020_8",
		[ENPC_DYRSTBROD] = "processEvent020_9",
	},
	[SEQ_033] = {
		[ENPC_BELI] = "processEvent033_10",
		[ENPC_DADALO] = "processEvent033_11",
		[ENPC_LALATTA] = "processEvent033_12",
	},
	[SEQ_035] = { [ENPC_LALATTA] = "processEvent033_12" },
	[SEQ_037] = {
		[ENPC_HEREWARD] = "processEvent033_6",
		[ENPC_LALATTA] = "processEvent037_2",
	},
};

MAIN = {
	[SEQ_000] = ENPC_LALATTA,
	[SEQ_010] = ENPC_LALATTA,
	[SEQ_020] = ENPC_LALATTA,
	[SEQ_030] = ENPC_HEREWARD,
	[SEQ_033] = ENPC_HEREWARD,
	[SEQ_035] = ENPC_HEREWARD,
	[SEQ_037] = ENPC_GYLBART,
};

-- Map markers (client marker block 11038001): each points at the next
-- cutscene, tan200<n>0 = processEvent0<n>0; steps between scenes have none.
MARKERS = {
	[SEQ_000] = 11038001;
	[SEQ_010] = 11038002;
	[SEQ_020] = 11038003;
	[SEQ_037] = 11038004;
	[SEQ_040] = 11038005;
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
	if (MAIN[sequence] ~= nil) then
		quest:SetENpc(MAIN[sequence], QFLAG_TALK);
	end
	if (sequence == SEQ_035) then
		quest:SetENpc(ENPC_STABLES, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_040) then
		quest:SetENpc(ENPC_HEREWARD, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();
	local data = quest:GetData();
	local bag = player:GetItemPackage(INVENTORY_NORMAL);

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_HEREWARD) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventHerewardStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (npcClassId == ENPC_LALATTA and seq == SEQ_000) then
		-- tan20010: the lancers storm off. It ends on an after-warp fade.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		quest:StartSequence(SEQ_010);
		player:EndEvent();
		GetWorldManager():DoZoneChange(player, LALATTA_SPOT[1], nil, 0, 15, LALATTA_SPOT[2], LALATTA_SPOT[3], LALATTA_SPOT[4], LALATTA_SPOT[5]);
		return;
	elseif (npcClassId == ENPC_LALATTA and seq == SEQ_010) then
		-- tan20020: she gives you the Wailers' armor to mend.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		bag:AddItem(ITEM_DAMAGED_ARMOR, 1, 1);
		quest:StartSequence(SEQ_020);
	elseif (npcClassId == ENPC_LALATTA and seq == SEQ_020) then
		if (bag:HasItem(ITEM_REPAIRED_ARMOR)) then
			-- The repair handed over; tan20030: her own attempt in tatters.
			-- It ends on an after-warp fade.
			bag:RemoveItem(ITEM_REPAIRED_ARMOR, 1);
			if (bag:HasItem(ITEM_DAMAGED_ARMOR)) then
				bag:RemoveItem(ITEM_DAMAGED_ARMOR, 1);
			end
			callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
			bag:AddItem(ITEM_ARMOR_REMNANTS, 1, 1);
			quest:StartSequence(SEQ_030);
			player:EndEvent();
			GetWorldManager():DoZoneChange(player, LALATTA_SPOT[1], nil, 0, 15, LALATTA_SPOT[2], LALATTA_SPOT[3], LALATTA_SPOT[4], LALATTA_SPOT[5]);
			return;
		end
		-- Not repaired yet.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_10");
	elseif (npcClassId == ENPC_HEREWARD and seq == SEQ_030) then
		-- More of the same leather, and bring the armor back for a look.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent033");
		quest:StartSequence(SEQ_033);
	elseif (npcClassId == ENPC_HEREWARD and seq == SEQ_033) then
		if (bag:HasItem(ITEM_REPAIRED_ARMOR)) then
			-- The new armor: he sends you to the stables in it.
			if (bag:HasItem(ITEM_ARMOR_REMNANTS)) then
				bag:RemoveItem(ITEM_ARMOR_REMNANTS, 1);
			end
			callClientFunction(player, "delegateEvent", player, quest, "processEvent033_3");
			quest:StartSequence(SEQ_035);
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent033_2");
		end
	elseif (npcClassId == ENPC_HEREWARD and seq == SEQ_035) then
		if (data:GetFlag(FLAG_WALKED)) then
			-- It will serve: off to Quarrymill.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent037");
			quest:StartSequence(SEQ_037);
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent033_4");
		end
	elseif (npcClassId == ENPC_GYLBART and seq == SEQ_037) then
		-- tan20040: the Wood Wailers take the armor.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent040");
		bag:RemoveItem(ITEM_REPAIRED_ARMOR, 1);
		quest:StartSequence(SEQ_040);
	elseif (npcClassId == ENPC_HEREWARD and seq == SEQ_040) then
		-- tan20050: Lalatta vouches for you, and payment.
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
	if (npcClassId == ENPC_STABLES and quest:GetSequence() == SEQ_035) then
		-- The walk is done; the client has no line for the stables.
		quest:GetData():SetFlag(FLAG_WALKED);
		quest:UpdateENPCs();
	end
	player:EndEvent();
end

function getJournalMapMarkerList(player, quest)
	return MARKERS[quest:GetSequence()];
end
