require ("global")
require ("quest")

--[[

Quest Script

Name:	Spanning the Spectrum
Code:	Wdk306
Id:	110302
Prereq: Level 36, Carpenter, Wdk300

Marcelloix means to take the children on an outing into the forest and
asks you to look after them while he gets leave. In the Acorn Orchard
they are making fairweather fetishes against rain (wdk30610); make one
and give it to Nicoliaux, and Marcelloix
comes back with leave granted (wdk30620). Nonolato at the Quiver's Hold
sends you to Wybir at Quarrymill to clear the way (processEvent023, 025).
A'naidjaa hears the way is safe and Marcelloix asks you along
(wdk30630). At the Mirror the children arrive (wdk30640), the rain comes
and everyone draws (wdk30650), Ryd asks you to draw for him
(processEvent055), and you wake Marcelloix to give him the drawings
(wdk30660), which ends back at the Oak Atrium with 36,000 gil and 3,600
experience.

Marcelloix ships stripped in 1.23b; the data gives him a class path and a
spot in the Oak Atrium. The bank of the Mirror (1091107) is a ???
object; the orchard is Wdk200's push circle (1091100). In the client the
fetish is a requested-items synthesis; the server has no such recipe yet,
but Nicoliaux still checks for the fetish and takes it. Wybir's fight while you craft arrows (says 142-146) was a
duty; it is not run here, and her briefing moves straight on. The
children have no actors at the orchard (bar Nicoliaux) or at the Mirror,
so their own lines there are left out.

Journal: rows 127-136 of the quest journal sheet. Map markers: see MARKERS.

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Find the children in the Acorn Orchard.
SEQ_010	= 10;  -- Make a fairweather fetish.
SEQ_020	= 20;  -- Speak with Nonolato.
SEQ_023	= 23;  -- Meet Wybir at Quarrymill.
SEQ_030	= 30;  -- Report to A'naidjaa.
SEQ_040	= 40;  -- Go to the Mirror.
SEQ_045	= 45;  -- The children have arrived.
SEQ_050	= 50;  -- Draw a picture.
SEQ_055	= 55;  -- Wake Marcelloix.

-- Actor Class Ids
ENPC_ANAIDJAA		= 1000465;
ENPC_HABREHAM		= 1000621;
ENPC_DECIMA			= 1000622;
ENPC_CHALYO_TAMLYO	= 1000623;
ENPC_CAPLAN			= 1000822;
ENPC_ULMHYLT		= 1000823;
ENPC_NICOLIAUX		= 1000409;
ENPC_NONOLATO		= 1000463;
ENPC_WYBIR			= 1000556;
ENPC_MARCELLOIX		= 1000596;
ENPC_ORCHARD		= 1091100; -- push circle in the Acorn Orchard (Wdk200's)
ENPC_MIRROR			= 1091107; -- ??? on the bank of the Mirror

ITEM_FAIRWEATHER_FETISH	= 11000065; -- crafted, normal bag

REWARD_GIL	= 36000;
REWARD_EXP	= 3600;

ORCHARD_SPOT = { 206, -36.0, 8.0, -1256.0, 0.0 };
MARCELLOIX_SPOT = { 206, 1.5, 8.75, -1259.5, -1.57 };
WYBIR_SPOT = { 154, 1443.0, -13.32, 878.0, -0.7 };
MIRROR_SPOT = { 150, 262.0, 5.46, -398.0, 0.0 };
ATRIUM_SPOT = { 206, 13.5, 8.75, -1265.2, -1.5 };

-- Guild chatter, speakers picked by the lines' content.
TALKS = {
	[SEQ_000] = {
		[ENPC_ANAIDJAA] = "processEvent005_2",
		[ENPC_DECIMA] = "processEvent005_3",
		[ENPC_CAPLAN] = "processEvent005_4",
		[ENPC_HABREHAM] = "processEvent005_5",
		[ENPC_CHALYO_TAMLYO] = "processEvent005_6",
		[ENPC_ULMHYLT] = "processEvent005_7",
	},
	[SEQ_010] = { [ENPC_ANAIDJAA] = "processEvent005_2" },
	[SEQ_020] = { [ENPC_ANAIDJAA] = "processEvent020_1" },
	[SEQ_023] = {
		[ENPC_ANAIDJAA] = "processEvent020_1",
		[ENPC_NONOLATO] = "processEvent023_1",
	},
	[SEQ_040] = {
		[ENPC_ANAIDJAA] = "processEvent030_2",
		[ENPC_DECIMA] = "processEvent030_3",
		[ENPC_CAPLAN] = "processEvent030_4",
		[ENPC_HABREHAM] = "processEvent030_5",
	},
};

MAIN = {
	[SEQ_000] = { ENPC_ORCHARD, QFLAG_PUSH },
	[SEQ_010] = { ENPC_NICOLIAUX, QFLAG_TALK },
	[SEQ_020] = { ENPC_NONOLATO, QFLAG_TALK },
	[SEQ_023] = { ENPC_WYBIR, QFLAG_TALK },
	[SEQ_030] = { ENPC_ANAIDJAA, QFLAG_TALK },
	[SEQ_040] = { ENPC_MIRROR, QFLAG_TALK },
	[SEQ_045] = { ENPC_MIRROR, QFLAG_TALK },
	[SEQ_050] = { ENPC_MIRROR, QFLAG_TALK },
	[SEQ_055] = { ENPC_MIRROR, QFLAG_REWARD },
};

-- Map markers (client marker block 11030201): each points at the next
-- cutscene, wdk306<n>0 = processEvent0<n>0; steps between scenes have none.
MARKERS = {
	[SEQ_000] = 11030201;
	[SEQ_010] = 11030202;
	[SEQ_030] = 11030203;
	[SEQ_040] = 11030204;
	[SEQ_045] = 11030205;
	[SEQ_055] = 11030206;
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_MARCELLOIX, QFLAG_TALK);
		return;
	end
	if (TALKS[sequence] ~= nil) then
		for classId, _ in pairs(TALKS[sequence]) do
			quest:SetENpc(classId);
		end
	end
	if (MAIN[sequence] ~= nil) then
		if (MAIN[sequence][2] == QFLAG_PUSH) then
			quest:SetENpc(MAIN[sequence][1], QFLAG_PUSH, false, true);
		else
			quest:SetENpc(MAIN[sequence][1], MAIN[sequence][2]);
		end
	end
end

local function warpTo(player, spot)
	GetWorldManager():DoZoneChange(player, spot[1], nil, 0, 15, spot[2], spot[3], spot[4], spot[5]);
end

local function afterWarpScene(player, quest, event, nextSeq, spot)
	callClientFunction(player, "delegateEvent", player, quest, event);
	quest:StartSequence(nextSeq);
	player:EndEvent();
	warpTo(player, spot);
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();
	local bag = player:GetItemPackage(INVENTORY_NORMAL);

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_MARCELLOIX) then
		-- The outing; watch the children (1 = accepted). Accepting ends on
		-- an after-warp fade.
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventMarcelloixStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
			player:EndEvent();
			warpTo(player, MARCELLOIX_SPOT);
			return;
		end
		player:EndEvent();
		return;
	elseif (npcClassId == ENPC_NICOLIAUX and seq == SEQ_010) then
		if (bag:HasItem(ITEM_FAIRWEATHER_FETISH)) then
			-- He takes yours; wdk30620: Marcelloix is back with leave. It ends
			-- on an after-warp fade.
			callClientFunction(player, "delegateEvent", player, quest, "processEventS002_2");
			bag:RemoveItem(ITEM_FAIRWEATHER_FETISH, 1);
			afterWarpScene(player, quest, "processEvent020", SEQ_020, ORCHARD_SPOT);
			return;
		end
		-- Not made one yet: his own fetish.
		callClientFunction(player, "delegateEvent", player, quest, "processEventS000_1");
	elseif (npcClassId == ENPC_NONOLATO and seq == SEQ_020) then
		-- Wybir is to scout the way, and asked for you.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent023");
		quest:StartSequence(SEQ_023);
	elseif (npcClassId == ENPC_WYBIR and seq == SEQ_023) then
		-- Wybir's plan; it ends on an after-warp fade (the duty that
		-- followed is not run).
		afterWarpScene(player, quest, "processEvent025", SEQ_030, WYBIR_SPOT);
		return;
	elseif (npcClassId == ENPC_ANAIDJAA and seq == SEQ_030) then
		-- wdk30630: the way is safe; Marcelloix asks you along.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
		quest:StartSequence(SEQ_040);
	elseif (npcClassId == ENPC_MIRROR and seq == SEQ_040) then
		-- wdk30640: the children arrive at the Mirror.
		afterWarpScene(player, quest, "processEvent040", SEQ_045, MIRROR_SPOT);
		return;
	elseif (npcClassId == ENPC_MIRROR and seq == SEQ_045) then
		-- wdk30650: rain, and drawing.
		afterWarpScene(player, quest, "processEvent050", SEQ_050, MIRROR_SPOT);
		return;
	elseif (npcClassId == ENPC_MIRROR and seq == SEQ_050) then
		-- Ryd wants a drawing: pick a color and a subject.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent055");
		quest:StartSequence(SEQ_055);
	elseif (npcClassId == ENPC_MIRROR and seq == SEQ_055) then
		-- wdk30660: Marcelloix wakes to the drawings; thanks and payment.
		-- It ends on an after-warp fade, back in the Oak Atrium.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent060");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 2);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddGil(REWARD_GIL);
		player:CompleteQuest(quest);
		player:EndEvent();
		warpTo(player, ATRIUM_SPOT);
		return;
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
		-- wdk30610: the children and their fetishes. After-warp.
		afterWarpScene(player, quest, "processEvent010", SEQ_010, ORCHARD_SPOT);
		return;
	end
	player:EndEvent();
end

function getJournalMapMarkerList(player, quest)
	return MARKERS[quest:GetSequence()];
end
