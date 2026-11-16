require ("global")
require ("quest")

--[[

Quest Script

Name:	Dance the Night Away
Code:	Wvr300
Id:	110401
Prereq: Level 30, Weaver

A royal ball is coming and Sunsilk Tapestries is swamped with orders.
Deaustie asks you to lend a hand (wvr30010, the choice is in the
cutscene) and, once Chuchumu's stepsisters have collected their gowns, to
help Chuchumu so she can go too. Chuchumu wants magic slippers from the
"green wizard" of Gridania. Soileine at Stillglade Fane sends you to the
Ebony Stalls, where Theldry has the midnight slippers but has promised
them to another buyer; talk up her shop and they are yours. Chuchumu gets
her slippers (wvr30020) and Deaustie pays 30,000 gil and 3,000 experience.

Simplified here: talking up Theldry's shop to four customers (the
processEventS001-S004 asks and the parley behind them) is left out, as the
customers have no actors; a second word with Theldry hands over the
slippers. Chuchumu (1000905, spawn 31060) and Theldry (1000379, spawn
31062) get public spawns.

Journal: steps 90-95 of the quest journal sheet (0B/45/08/4E).

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Speak with Chuchumu.
SEQ_012	= 12;  -- Find the green wizard in Gridania.
SEQ_015	= 15;  -- Ask at the Ebony Stalls.
SEQ_018	= 18;  -- Earn Theldry's slippers.
SEQ_019	= 19;  -- Bring the slippers to Chuchumu.
SEQ_020	= 20;  -- Back to Deaustie for the reward.

-- Actor Class Ids
ENPC_DEAUSTIE		= 1000293;
ENPC_LOHWAEB		= 1000644;
ENPC_MARGARETE		= 1000645;
ENPC_RINH_MAIMHOV	= 1000646;
ENPC_CAHERNAUT		= 1000915;
ENPC_ASPIPI			= 1000916;
ENPC_GLOIUCEN		= 1000917;
ENPC_CHUCHUMU		= 1000905; -- Sunsilk Tapestries
ENPC_SOILEINE		= 1000234; -- Stillglade Fane, Gridania
ENPC_THELDRY		= 1000379; -- Ebony Stalls, Gridania

ITEM_MIDNIGHT_SLIPPERS	= 11000139; -- key item

REWARD_GIL	= 30000;
REWARD_EXP	= 3000;

-- Markers (01/03/05/A9: one per cutscene).
MRKR_SUNSILK	= 11040101; -- wvr30010
MRKR_CHUCHUMU	= 11040102; -- wvr30020

-- In front of Deaustie and of Chuchumu at Sunsilk Tapestries.
ULDAH_ZONE = 209;
DEAUSTIE_SPOT = { 40.8, 195.59, 258.29, -1.77 };
CHUCHUMU_SPOT = { 50.0, 194.2, 251.0, -3.14 };

-- The weavers' chatter; slot 2 is Deaustie, the other slots go to the same
-- weavers as in Wvr200.
WEAVERS_010 = {
	[ENPC_DEAUSTIE] = "processEvent010_2",
	[ENPC_LOHWAEB] = "processEvent010_3",
	[ENPC_MARGARETE] = "processEvent010_4",
	[ENPC_RINH_MAIMHOV] = "processEvent010_5",
	[ENPC_CAHERNAUT] = "processEvent010_6",
	[ENPC_ASPIPI] = "processEvent010_7",
	[ENPC_GLOIUCEN] = "processEvent010_8",
};
WEAVERS_015 = {
	[ENPC_DEAUSTIE] = "processEvent015_2",
	[ENPC_LOHWAEB] = "processEvent015_3",
	[ENPC_MARGARETE] = "processEvent015_4",
	[ENPC_RINH_MAIMHOV] = "processEvent015_5",
	[ENPC_CAHERNAUT] = "processEvent015_6",
	[ENPC_ASPIPI] = "processEvent015_7",
	[ENPC_GLOIUCEN] = "processEvent015_8",
};
-- In Gridania Chuchumu repeats her wish; once you have the slippers she
-- is the one to talk to.
WEAVERS_015_CHUCHUMU = { [ENPC_CHUCHUMU] = "processEvent012_1" };
for classId, fn in pairs(WEAVERS_015) do
	WEAVERS_015_CHUCHUMU[classId] = fn;
end

TALKS = {
	[SEQ_000] = WEAVERS_010,
	[SEQ_012] = {
		[ENPC_DEAUSTIE] = "processEvent012_2",
		[ENPC_LOHWAEB] = "processEvent010_3",
		[ENPC_MARGARETE] = "processEvent010_4",
		[ENPC_RINH_MAIMHOV] = "processEvent010_5",
		[ENPC_CAHERNAUT] = "processEvent010_6",
		[ENPC_ASPIPI] = "processEvent010_7",
		[ENPC_GLOIUCEN] = "processEvent010_8",
		[ENPC_CHUCHUMU] = "processEvent012_1",
	},
	[SEQ_015] = WEAVERS_015_CHUCHUMU,
	[SEQ_018] = WEAVERS_015_CHUCHUMU,
	[SEQ_019] = WEAVERS_015,
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_DEAUSTIE, QFLAG_TALK);
		return;
	end
	if (TALKS[sequence] ~= nil) then
		for classId, _ in pairs(TALKS[sequence]) do
			quest:SetENpc(classId);
		end
	end
	if (sequence == SEQ_000 or sequence == SEQ_019) then
		quest:SetENpc(ENPC_CHUCHUMU, QFLAG_TALK);
	elseif (sequence == SEQ_012) then
		quest:SetENpc(ENPC_SOILEINE, QFLAG_TALK);
	elseif (sequence == SEQ_015 or sequence == SEQ_018) then
		quest:SetENpc(ENPC_THELDRY, QFLAG_TALK);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(ENPC_DEAUSTIE, QFLAG_REWARD);
	end
end

local function warpTo(player, zoneId, spot)
	GetWorldManager():DoZoneChange(player, zoneId, nil, 0, 15, spot[1], spot[2], spot[3], spot[4]);
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_DEAUSTIE) then
		-- wvr30010: the ball, the orders and the stepsisters; the choice is
		-- made in the cutscene (1 = accepted, then an after-warp fade).
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventDeaustieStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
			player:EndEvent();
			warpTo(player, ULDAH_ZONE, DEAUSTIE_SPOT);
			return;
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and npcClassId == ENPC_CHUCHUMU) then
		-- Chuchumu's wish: slippers from the green wizard of Gridania.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent012");
		quest:StartSequence(SEQ_012);
	elseif (seq == SEQ_012 and npcClassId == ENPC_SOILEINE) then
		-- No wizards here; try the merchants of the Ebony Stalls.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent015");
		quest:StartSequence(SEQ_015);
	elseif (seq == SEQ_015 and npcClassId == ENPC_THELDRY) then
		-- Theldry has the slippers, but they are promised to another.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent018");
		quest:StartSequence(SEQ_018);
	elseif (seq == SEQ_018 and npcClassId == ENPC_THELDRY) then
		-- Her shop is suddenly busy: the slippers are yours.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent019");
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(ITEM_MIDNIGHT_SLIPPERS, 1, 1);
		quest:StartSequence(SEQ_019);
	elseif (seq == SEQ_019 and npcClassId == ENPC_CHUCHUMU) then
		-- wvr30020: the slippers, and Chuchumu off to the ball (after-warp
		-- fade).
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(ITEM_MIDNIGHT_SLIPPERS, 1);
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		quest:StartSequence(SEQ_020);
		player:EndEvent();
		warpTo(player, ULDAH_ZONE, CHUCHUMU_SPOT);
		return;
	elseif (seq == SEQ_020 and npcClassId == ENPC_DEAUSTIE) then
		-- Deaustie's thanks, and payment.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
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
	player:EndEvent();
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:GetSequence();
	if (seq == SEQ_000 or seq == SEQ_020) then
		return MRKR_SUNSILK;
	elseif (seq == SEQ_019) then
		return MRKR_CHUCHUMU;
	end
end
