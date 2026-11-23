require ("global")
require ("quest")

--[[

Quest Script

Name:	Polishing the Mast
Code:	Fsh306
Id:	110502
Prereq: Level 36, Fisher

N'nmulika invites you to the pullers' meeting, where the guild airs its
grievances against Netmaster Wawalago, who wriggles out of it by calling a
sale (fsh30610). N'nmulika tells you which catch the guild is buying (a
nautilus); bring one in for 1,000 gil before the sale closes (fsh30620).
Some pullers got an extension, so you go to ask for one too: at the
netmaster's door Sisipu and Maisie were turned away (fsh30630), and the
Echo shows why he makes new pullers dance in their underclothes (fsh30640,
fsh30650, fsh30660). N'nmulika pays 36,000 gil and 3,600 experience
(processEvent070).

Wawalago has no class path in 1.23b: his meeting plays when you next speak
with N'nmulika. Sisipu stands at her public spawn in the guild (31044, see
Fsh300).

Journal: steps 87-92 of the quest journal sheet (0B/45/08/1B).

]]

-- Sequence Numbers
SEQ_000	= 0;   -- The pullers' meeting.
SEQ_010	= 10;  -- Ask N'nmulika how to take part in the sale.
SEQ_015	= 15;  -- Bring in a nautilus.
SEQ_020	= 20;  -- Ask the netmaster for an extension.
SEQ_030	= 30;  -- Use the Echo on Sisipu.
SEQ_040	= 40;  -- ...and again.
SEQ_050	= 50;  -- Use the Echo on Maisie.
SEQ_060	= 60;  -- N'nmulika has your pay.

-- Actor Class Ids
ENPC_NNMULIKA		= 1000153;
ENPC_SISIPU			= 1000155;
ENPC_MAISIE			= 1000173;
ENPC_ASTRID			= 1000180;
ENPC_XAVALIEN		= 1000181;
ENPC_CLIFTON		= 1000199;
ENPC_UNDSATZ		= 1000200;
ENPC_RERENASU		= 1000201;
ENPC_DACA_JINJAHL	= 1000202;
ENPC_SKOEFMYND		= 1000662;

ITEM_NAUTILUS	= 3011203; -- the catch the guild asks for (ZAM)
SALE_GIL		= 1000;

REWARD_GIL	= 36000;
REWARD_EXP	= 3600;

-- In front of N'nmulika.
LIMSA_ZONE = 230;
GUILD_SPOT = { -611.9, 4.55, 342.57, -2.45 };

-- The pullers' chatter. No speaker is named; these follow the lines'
-- content (Undsatz names himself, Rerenasu courts Sisipu).
TALKS_005 = {
	[ENPC_ASTRID] = "processEvent005_3",
	[ENPC_SKOEFMYND] = "processEvent005_4",
	[ENPC_XAVALIEN] = "processEvent005_5",
	[ENPC_MAISIE] = "processEvent005_6",
};
TALKS_010 = {
	[ENPC_ASTRID] = "processEvent010_2",
	[ENPC_SKOEFMYND] = "processEvent010_3",
	[ENPC_UNDSATZ] = "processEvent010_4",
	[ENPC_RERENASU] = "processEvent010_5",
	[ENPC_SISIPU] = "processEvent010_6",
	[ENPC_CLIFTON] = "processEvent010_7",
	[ENPC_XAVALIEN] = "processEvent010_8",
	[ENPC_DACA_JINJAHL] = "processEvent010_9",
	[ENPC_MAISIE] = "processEvent010_10",
};
TALKS_020 = {
	[ENPC_NNMULIKA] = "processEvent020_2",
	[ENPC_ASTRID] = "processEvent020_3",
	[ENPC_SKOEFMYND] = "processEvent020_4",
	[ENPC_UNDSATZ] = "processEvent020_5",
	[ENPC_RERENASU] = "processEvent020_6",
	[ENPC_CLIFTON] = "processEvent020_7",
	[ENPC_XAVALIEN] = "processEvent020_8",
	[ENPC_DACA_JINJAHL] = "processEvent020_9",
	[ENPC_MAISIE] = "processEvent020_10",
};
TALKS = {
	[SEQ_000] = TALKS_005,
	[SEQ_010] = TALKS_010,
	[SEQ_015] = TALKS_010,
	[SEQ_020] = TALKS_020,
	[SEQ_030] = TALKS_020,
	[SEQ_040] = TALKS_020,
	[SEQ_050] = TALKS_020,
	[SEQ_060] = TALKS_020,
};

-- Who carries each step (they take precedence over the chatter).
OBJECTIVES = {
	[SEQ_000] = { ENPC_NNMULIKA, QFLAG_TALK },
	[SEQ_010] = { ENPC_NNMULIKA, QFLAG_TALK },
	[SEQ_015] = { ENPC_NNMULIKA, QFLAG_TALK },
	[SEQ_020] = { ENPC_SISIPU, QFLAG_TALK },
	[SEQ_030] = { ENPC_SISIPU, QFLAG_TALK },
	[SEQ_040] = { ENPC_SISIPU, QFLAG_TALK },
	[SEQ_050] = { ENPC_MAISIE, QFLAG_TALK },
	[SEQ_060] = { ENPC_NNMULIKA, QFLAG_REWARD },
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_NNMULIKA, QFLAG_TALK);
		return;
	end
	local objective = OBJECTIVES[sequence];
	if (TALKS[sequence] ~= nil) then
		for classId, _ in pairs(TALKS[sequence]) do
			if (objective == nil or classId ~= objective[1]) then
				quest:SetENpc(classId);
			end
		end
	end
	if (sequence == SEQ_050 or sequence == SEQ_060) then
		quest:SetENpc(ENPC_SISIPU);
	end
	if (objective ~= nil) then
		quest:SetENpc(objective[1], objective[2]);
	end
end

local function warpTo(player, spot)
	GetWorldManager():DoZoneChange(player, LIMSA_ZONE, nil, 0, 15, spot[1], spot[2], spot[3], spot[4]);
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_NNMULIKA) then
		-- The meeting on the guild's running (1 = accepted).
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventNnmulikaStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and npcClassId == ENPC_NNMULIKA) then
		-- fsh30610: the grievances, and the netmaster's sale. It ends on an
		-- after-warp fade.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		quest:StartSequence(SEQ_010);
		player:EndEvent();
		warpTo(player, GUILD_SPOT);
		return;
	elseif (seq == SEQ_010 and npcClassId == ENPC_NNMULIKA) then
		-- Which catch to bring in. Its line names the catch with an item
		-- macro, but given an item id (any id, not only the nautilus) the
		-- client's macro times out with a script error and the event never
		-- returns: no input until a relog. Without it the line still plays.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent015");
		quest:StartSequence(SEQ_015);
	elseif (seq == SEQ_015 and npcClassId == ENPC_NNMULIKA) then
		if (player:GetItemPackage(INVENTORY_NORMAL):HasItem(ITEM_NAUTILUS, 1)) then
			-- Bought for the sale, then fsh30620: the sale closes. It ends
			-- on an after-warp fade.
			player:GetItemPackage(INVENTORY_NORMAL):RemoveItem(ITEM_NAUTILUS, 1);
			callClientFunction(player, "delegateEvent", player, quest, "processEvent015_3", nil, 1); -- no item id: see SEQ_010
			player:AddGil(SALE_GIL);
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
			quest:StartSequence(SEQ_020);
			player:EndEvent();
			warpTo(player, GUILD_SPOT);
			return;
		end
		callClientFunction(player, "delegateEvent", player, quest, "processEvent016");
	elseif (seq == SEQ_020 and npcClassId == ENPC_SISIPU) then
		-- fsh30630: turned away at the netmaster's door.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
		quest:StartSequence(SEQ_030);
	elseif (seq == SEQ_030 and npcClassId == ENPC_SISIPU) then
		-- The Echo (fsh30640): the man overboard.
		if (callClientFunction(player, "delegateEvent", player, quest, "processEvent040") == 1) then
			quest:StartSequence(SEQ_040);
		end
	elseif (seq == SEQ_040 and npcClassId == ENPC_SISIPU) then
		-- The Echo (fsh30650): the netmaster jilted.
		if (callClientFunction(player, "delegateEvent", player, quest, "processEvent050") == 1) then
			quest:StartSequence(SEQ_050);
		end
	elseif (seq == SEQ_050 and npcClassId == ENPC_MAISIE) then
		-- The Echo (fsh30660).
		if (callClientFunction(player, "delegateEvent", player, quest, "processEvent060") == 1) then
			quest:StartSequence(SEQ_060);
		end
	elseif ((seq == SEQ_050 or seq == SEQ_060) and npcClassId == ENPC_SISIPU) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050_2");
	elseif (seq == SEQ_060 and npcClassId == ENPC_MAISIE) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent060_2");
	elseif (seq == SEQ_060 and npcClassId == ENPC_NNMULIKA) then
		-- N'nmulika's thanks, and payment.
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

-- Quest markers by sequence: each names the scene that ends the step in
-- the client's marker index (01/03/05/A9, scene names in A8).
MARKERS = {
	[SEQ_000] = 11050201; -- fsh30610
	[SEQ_015] = 11050202; -- fsh30620
	[SEQ_020] = 11050203; -- fsh30630
	[SEQ_030] = 11050204; -- fsh30640
	[SEQ_040] = 11050205; -- fsh30650
	[SEQ_050] = 11050206; -- fsh30660
};

function getJournalMapMarkerList(player, quest)
	return MARKERS[quest:getSequence()];
end
