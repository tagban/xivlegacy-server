require ("global")
require ("quest")

--[[

Quest Script

Name:	Hide and Seek Shenanigans
Code:	Wdk300
Id:	110301
Prereq: Level 30, Carpenter, Wdk200

A'naidjaa asks you to mind the children while Marcelloix is away. Behind
the workshop door Marcelloix leaves you with them (wdk30010); bored, they
run off to play hide-and-seek (wdk30020). Nicoliaux is in the Acorn
Orchard and points you to Ryd at the Wailing Barracks; Ryd gives away
Powle, who is hiding in a box out front (knock, shake and kick it). At the
Quiver's Hold Elyn sends you up a tree and under the hall before telling
you Aunillie never left the Atrium, and hands you a hat and a toy. Back at
the workshop door the children are called to eat (wdk30030). A'naidjaa has
you take toys to the sick children at Frondale's Phrontistery in Ul'dah
(wdk30040); Nogeloix thanks you and gives you Marcelloix's medicine
(wdk30050). A'naidjaa tells of a ghost haunting the Atrium (processEvent055)
and sends you to the Roost, where V'korolon calls the masked Marcelloix
(processEvent060, wdk30060). A'naidjaa pays 30,000 gil and 3,000
experience (processEvent070).

The workshop door is a ??? object (1091104) and Powle's box another
(1091105). Ryd and Elyn get spots at their hiding places. The client's
"no one here" checks of empty spots (S000_2, S001_2, S003_2, S003_4) and
the children's lines inside the workshop have no actor to hang on and are
left out; the parleys are reduced to talking to each child again.

Journal: rows 115-126 of the quest journal sheet. Map markers: see MARKERS.

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Go through the workshop door.
SEQ_010	= 10;  -- Keep the children in the workshop.
SEQ_020	= 20;  -- Hide-and-seek: find the children.
SEQ_021	= 21;  -- Nicoliaux found: get him to talk.
SEQ_022	= 22;  -- Look for Ryd at the Wailing Barracks.
SEQ_023	= 23;  -- Powle is in a box.
SEQ_024	= 24;  -- Find Elyn by the Quiver's Hold.
SEQ_026	= 26;  -- Take everyone back to the workshop.
SEQ_030	= 30;  -- Speak with A'naidjaa.
SEQ_040	= 40;  -- Take the toys to Frondale's Phrontistery.
SEQ_050	= 50;  -- Report to A'naidjaa.
SEQ_055	= 55;  -- Bring the medicine to Marcelloix at the Roost.
SEQ_060	= 60;  -- A'naidjaa has your reward.

-- Actor Class Ids
ENPC_ANAIDJAA		= 1000465;
ENPC_HABREHAM		= 1000621;
ENPC_DECIMA			= 1000622;
ENPC_CHALYO_TAMLYO	= 1000623;
ENPC_NELLAURE		= 1000821;
ENPC_CAPLAN			= 1000822;
ENPC_ULMHYLT		= 1000823;
ENPC_NICOLIAUX		= 1000409;
ENPC_ELYN			= 1000411;
ENPC_RYD			= 1000412;
ENPC_JOLLINE		= 1000069; -- at the Wailing Barracks' counter
ENPC_NOGELOIX		= 1000597;
ENPC_VKOROLON		= 1000458;
ENPC_WORKSHOP_DOOR	= 1091104; -- ??? on the workshop door
ENPC_POWLE_BOX		= 1091105; -- ??? on Powle's box

-- Elyn's gifts (S003_6).
ITEM_BUILDING_BLOCK	= 11000029; -- key item
ITEM_SUGARLOAF_HAT	= 8010932;

REWARD_GIL	= 30000;
REWARD_EXP	= 3000;

-- Counter 0: how far Elyn has led you on.
COUNTER_ELYN = 0;

DOOR_SPOT = { 206, -11.0, 12.07, -1252.0, 0.0 };

-- Guild chatter, speakers picked by the lines' content. Ulmhylt is named
-- in Marcelloix's own story as the one who found the timber.
TALKS = {
	[SEQ_000] = {
		[ENPC_ANAIDJAA] = "processEvent005_2",
		[ENPC_DECIMA] = "processEvent005_3",
		[ENPC_CAPLAN] = "processEvent005_4",
		[ENPC_HABREHAM] = "processEvent005_5",
		[ENPC_CHALYO_TAMLYO] = "processEvent005_6",
		[ENPC_ULMHYLT] = "processEvent005_7",
	},
	[SEQ_010] = { [ENPC_ANAIDJAA] = "processEventS000_0" },
	[SEQ_020] = { [ENPC_ANAIDJAA] = "processEventS000_0" },
	[SEQ_021] = { [ENPC_ANAIDJAA] = "processEventS000_0" },
	[SEQ_022] = {
		[ENPC_ANAIDJAA] = "processEventS000_0",
		[ENPC_NICOLIAUX] = "processEventS000_5",
		[ENPC_JOLLINE] = "processEventS001_1",
	},
	[SEQ_023] = {
		[ENPC_ANAIDJAA] = "processEventS000_0",
		[ENPC_NICOLIAUX] = "processEventS000_5",
		[ENPC_RYD] = "processEventS002_5",
	},
	[SEQ_024] = {
		[ENPC_ANAIDJAA] = "processEventS000_0",
		[ENPC_NICOLIAUX] = "processEventS000_5",
		[ENPC_RYD] = "processEventS002_5",
	},
	[SEQ_026] = {
		[ENPC_ANAIDJAA] = "processEventS000_0",
		[ENPC_NICOLIAUX] = "processEventS000_5",
		[ENPC_RYD] = "processEventS002_5",
	},
	[SEQ_030] = { [ENPC_NELLAURE] = "processEvent025_2" },
	[SEQ_040] = {
		[ENPC_ANAIDJAA] = "processEvent040_2",
		[ENPC_DECIMA] = "processEvent040_3",
		[ENPC_CAPLAN] = "processEvent040_4",
		[ENPC_HABREHAM] = "processEvent040_5",
		[ENPC_CHALYO_TAMLYO] = "processEvent040_6",
		[ENPC_ULMHYLT] = "processEvent040_7",
	},
	[SEQ_050] = {
		[ENPC_NOGELOIX] = "processEvent050_7",
		[ENPC_NELLAURE] = "processEvent050_2",
		[ENPC_DECIMA] = "processEvent050_3",
		[ENPC_CAPLAN] = "processEvent050_4",
		[ENPC_CHALYO_TAMLYO] = "processEvent050_5",
		[ENPC_HABREHAM] = "processEvent050_6",
	},
	[SEQ_055] = {
		[ENPC_ANAIDJAA] = "processEvent055_2",
		[ENPC_NOGELOIX] = "processEvent050_7",
	},
};

-- Who moves the step on, and with which client handler.
MAIN = {
	[SEQ_000] = { ENPC_WORKSHOP_DOOR, QFLAG_TALK },
	[SEQ_010] = { ENPC_WORKSHOP_DOOR, QFLAG_TALK },
	[SEQ_020] = { ENPC_NICOLIAUX, QFLAG_TALK },
	[SEQ_021] = { ENPC_NICOLIAUX, QFLAG_TALK },
	[SEQ_022] = { ENPC_RYD, QFLAG_TALK },
	[SEQ_023] = { ENPC_POWLE_BOX, QFLAG_TALK },
	[SEQ_024] = { ENPC_ELYN, QFLAG_TALK },
	[SEQ_026] = { ENPC_WORKSHOP_DOOR, QFLAG_TALK },
	[SEQ_030] = { ENPC_ANAIDJAA, QFLAG_TALK },
	[SEQ_040] = { ENPC_NOGELOIX, QFLAG_TALK },
	[SEQ_050] = { ENPC_ANAIDJAA, QFLAG_TALK },
	[SEQ_055] = { ENPC_VKOROLON, QFLAG_TALK },
	[SEQ_060] = { ENPC_ANAIDJAA, QFLAG_REWARD },
};

-- Elyn's three answers, in order.
ELYN_TALKS = { "processEventS003_1", "processEventS003_3", "processEventS003_6" };

-- Map markers (client marker block 11030101): each points at the next
-- cutscene, wdk300<n>0 = processEvent0<n>0; steps between scenes have none.
MARKERS = {
	[SEQ_000] = 11030101;
	[SEQ_010] = 11030102;
	[SEQ_026] = 11030103;
	[SEQ_030] = 11030104;
	[SEQ_040] = 11030105;
	[SEQ_055] = 11030106;
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
	if (MAIN[sequence] ~= nil) then
		quest:SetENpc(MAIN[sequence][1], MAIN[sequence][2]);
	end
end

local function warpTo(player, spot)
	GetWorldManager():DoZoneChange(player, spot[1], nil, 0, 15, spot[2], spot[3], spot[4], spot[5]);
end

-- A scene that ends on an after-warp fade, then the next step.
local function afterWarpScene(player, quest, event, nextSeq, spot)
	callClientFunction(player, "delegateEvent", player, quest, event);
	quest:StartSequence(nextSeq);
	player:EndEvent();
	warpTo(player, spot);
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();
	local data = quest:GetData();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_ANAIDJAA) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventANaidjaaStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (npcClassId == ENPC_WORKSHOP_DOOR and seq == SEQ_000) then
		-- wdk30010: Marcelloix leaves you with the children.
		afterWarpScene(player, quest, "processEvent010", SEQ_010, DOOR_SPOT);
		return;
	elseif (npcClassId == ENPC_WORKSHOP_DOOR and seq == SEQ_010) then
		-- wdk30020: hide-and-seek, and you're it.
		afterWarpScene(player, quest, "processEvent020", SEQ_020, DOOR_SPOT);
		return;
	elseif (npcClassId == ENPC_WORKSHOP_DOOR and seq == SEQ_026) then
		-- wdk30030: Aunillie, and the call to eat.
		afterWarpScene(player, quest, "processEvent030", SEQ_030, DOOR_SPOT);
		return;
	elseif (npcClassId == ENPC_NICOLIAUX and seq == SEQ_020) then
		-- Found in the orchard.
		callClientFunction(player, "delegateEvent", player, quest, "processEventS000_1");
		quest:StartSequence(SEQ_021);
	elseif (npcClassId == ENPC_NICOLIAUX and seq == SEQ_021) then
		-- He gives nothing away, then lets slip where Ryd likes to be.
		callClientFunction(player, "delegateEvent", player, quest, "processEventS000_5");
		callClientFunction(player, "delegateEvent", player, quest, "processEventS000_6");
		quest:StartSequence(SEQ_022);
	elseif (npcClassId == ENPC_RYD and seq == SEQ_022) then
		-- Ryd, found, tells on Powle.
		callClientFunction(player, "delegateEvent", player, quest, "processEventS001_3");
		callClientFunction(player, "delegateEvent", player, quest, "processEventS001_4");
		quest:StartSequence(SEQ_023);
	elseif (npcClassId == ENPC_POWLE_BOX and seq == SEQ_023) then
		-- Knock, shake and kick (1 = all three): Powle comes out.
		local out = callClientFunction(player, "delegateEvent", player, quest, "processEventS001_5");
		if (out == 1) then
			quest:StartSequence(SEQ_024);
		end
	elseif (npcClassId == ENPC_ELYN and seq == SEQ_024) then
		-- Up the tree, under the hall, then the truth (and her gifts).
		local step = data:GetCounter(COUNTER_ELYN);
		if (step >= #ELYN_TALKS - 1) then
			callClientFunction(player, "delegateEvent", player, quest, ELYN_TALKS[#ELYN_TALKS]);
			player:GetItemPackage(INVENTORY_NORMAL):AddItem(ITEM_SUGARLOAF_HAT, 1, 1);
			player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(ITEM_BUILDING_BLOCK, 1, 1);
			quest:StartSequence(SEQ_026);
		else
			callClientFunction(player, "delegateEvent", player, quest, ELYN_TALKS[step + 1]);
			data:IncCounter(COUNTER_ELYN);
		end
	elseif (npcClassId == ENPC_ANAIDJAA and seq == SEQ_030) then
		-- wdk30040: the toys, and an errand to Ul'dah.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent040");
		quest:StartSequence(SEQ_040);
	elseif (npcClassId == ENPC_NOGELOIX and seq == SEQ_040) then
		-- wdk30050: the Phrontistery takes the toys and sends medicine.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050");
		quest:StartSequence(SEQ_050);
	elseif (npcClassId == ENPC_ANAIDJAA and seq == SEQ_050) then
		-- The Atrium's ghost: did you start the rumors? Either way, to the Roost.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent055");
		quest:StartSequence(SEQ_055);
	elseif (npcClassId == ENPC_VKOROLON and seq == SEQ_055) then
		-- V'korolon calls Marcelloix (wdk30060).
		callClientFunction(player, "delegateEvent", player, quest, "processEvent060");
		quest:StartSequence(SEQ_060);
	elseif (npcClassId == ENPC_ANAIDJAA and seq == SEQ_060) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent070");
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
	return MARKERS[quest:GetSequence()];
end
