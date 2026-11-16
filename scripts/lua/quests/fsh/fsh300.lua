require ("global")
require ("quest")

--[[

Quest Script

Name:	The Beast of the Barrel
Code:	Fsh300
Id:	110501
Prereq: Level 30, Fisher

N'nmulika lends you to Sisipu, who hands you a bucket of feed for the fish
of the Barrel (fsh30010). Rerenasu rows you across; while you feed the fish
a mustachioed stranger has you dance for them (fsh30020), then sends you to
Ul'dah for proper attire (fsh30025). Rorojaru sells you the outfit, and
back at the Barrel the stranger has you dance again (fsh30030), catch a
fish to prove his point (fsh30040) and sends you home (fsh30050). Sisipu
hears the tale and storms off (fsh30060); at the netmaster's door the Echo
shows the stranger was Wawalago (fsh30070). N'nmulika apologizes and pays
30,000 gil and 3,000 experience (processEvent075).

Simplified here: the Barrel has no place on this server, so each crossing
with Rerenasu plays the Barrel's scenes back to back (the dance to the
schools of fish, an emote game the 1.23b client script doesn't carry, and
the catch are left out). Sisipu only stood in instances in 1.23b; she gets
a public spawn in the guild (31044) for her scenes here and in Fsh306.

Journal: steps 76-86 of the quest journal sheet (0B/45/08/1B).

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Find Sisipu.
SEQ_010	= 10;  -- Take the feed to the Barrel (Rerenasu's dinghy).
SEQ_028	= 28;  -- Find Rorojaru in Ul'dah.
SEQ_029	= 29;  -- Back to the Barrel in your new outfit.
SEQ_050	= 50;  -- Tell Sisipu what happened.
SEQ_060	= 60;  -- Follow her: the Echo at the netmaster's door.
SEQ_070	= 70;  -- N'nmulika has your pay.

-- Actor Class Ids
ENPC_NNMULIKA		= 1000153;
ENPC_SISIPU			= 1000155;
ENPC_MAISIE			= 1000173;
ENPC_ASTRID			= 1000180;
ENPC_XAVALIEN		= 1000181;
ENPC_UNDSATZ		= 1000200;
ENPC_RERENASU		= 1000201;
ENPC_DACA_JINJAHL	= 1000202;
ENPC_BLOEMERL		= 1000203;
ENPC_SKOEFMYND		= 1000662;
ENPC_ROROJARU		= 1000374; -- Sapphire Avenue, Ul'dah

ITEM_BARREL_FEED	= 11000025; -- key item from Sisipu

REWARD_GIL	= 30000;
REWARD_EXP	= 3000;

-- Fisherman's Bottom: in front of N'nmulika, and on the dock by Rerenasu.
LIMSA_ZONE = 230;
GUILD_SPOT = { -611.9, 4.55, 342.57, -2.45 };
DOCK_SPOT = { -639.1, 1.0, 400.38, -0.87 };

-- The pullers' chatter. No speaker is named; these follow the lines'
-- content (Daca Jinjahl speaks to Bloemerl, who answers; Xavalien is
-- "Xavie").
TALKS = {
	[SEQ_000] = {
		[ENPC_NNMULIKA] = "processEvent010_1000",
	},
	[SEQ_010] = {
		[ENPC_SISIPU] = "processEvent010_2",
		[ENPC_ASTRID] = "processEvent10_3",
		[ENPC_SKOEFMYND] = "processEvent10_4",
		[ENPC_XAVALIEN] = "processEvent10_5",
		[ENPC_DACA_JINJAHL] = "processEvent10_6",
		[ENPC_BLOEMERL] = "processEvent10_7",
		[ENPC_UNDSATZ] = "processEvent10_8",
		[ENPC_NNMULIKA] = "processEvent10_9",
		[ENPC_MAISIE] = "processEvent10_10",
	},
	[SEQ_028] = {
		[ENPC_NNMULIKA] = "processEvent025_2",
		[ENPC_ASTRID] = "processEvent025_3",
		[ENPC_SKOEFMYND] = "processEvent025_4",
		[ENPC_XAVALIEN] = "processEvent025_5",
		[ENPC_MAISIE] = "processEvent025_6",
		[ENPC_UNDSATZ] = "processEvent025_7",
	},
	[SEQ_029] = {
		[ENPC_NNMULIKA] = "processEvent028_3",
		[ENPC_ASTRID] = "processEvent028_4",
		[ENPC_SKOEFMYND] = "processEvent028_5",
		[ENPC_DACA_JINJAHL] = "processEvent028_6",
		[ENPC_BLOEMERL] = "processEvent028_7",
		[ENPC_XAVALIEN] = "processEvent028_8",
		[ENPC_MAISIE] = "processEvent028_9",
	},
	[SEQ_060] = {
		[ENPC_NNMULIKA] = "processEvent050_2",
		[ENPC_ASTRID] = "processEvent050_3",
		[ENPC_SKOEFMYND] = "processEvent050_4",
		[ENPC_UNDSATZ] = "processEvent050_5",
		[ENPC_DACA_JINJAHL] = "processEvent050_6",
		[ENPC_BLOEMERL] = "processEvent050_7",
		[ENPC_XAVALIEN] = "processEvent050_8",
		[ENPC_MAISIE] = "processEvent050_9",
	},
	[SEQ_070] = {
		[ENPC_SISIPU] = "processEvent070_2",
		[ENPC_ASTRID] = "processEvent050_3",
		[ENPC_SKOEFMYND] = "processEvent050_4",
		[ENPC_UNDSATZ] = "processEvent050_5",
		[ENPC_DACA_JINJAHL] = "processEvent050_6",
		[ENPC_BLOEMERL] = "processEvent050_7",
		[ENPC_XAVALIEN] = "processEvent050_8",
		[ENPC_MAISIE] = "processEvent050_9",
	},
};
-- Back from Ul'dah, before Sisipu hears of it: same as on the way back.
TALKS[SEQ_050] = TALKS[SEQ_029];

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
	if (TALKS[sequence] ~= nil) then
		for classId, _ in pairs(TALKS[sequence]) do
			quest:SetENpc(classId);
		end
	end
	if (sequence == SEQ_000 or sequence == SEQ_050 or sequence == SEQ_060) then
		quest:SetENpc(ENPC_SISIPU, QFLAG_TALK);
	elseif (sequence == SEQ_010 or sequence == SEQ_029) then
		quest:SetENpc(ENPC_RERENASU, QFLAG_TALK);
	elseif (sequence == SEQ_028) then
		quest:SetENpc(ENPC_ROROJARU, QFLAG_TALK);
	elseif (sequence == SEQ_070) then
		quest:SetENpc(ENPC_NNMULIKA, QFLAG_REWARD);
	end
end

local function warpTo(player, spot)
	GetWorldManager():DoZoneChange(player, LIMSA_ZONE, nil, 0, 15, spot[1], spot[2], spot[3], spot[4]);
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_NNMULIKA) then
		-- A job with your name on it (1 = accepted).
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventNnmulikaStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and npcClassId == ENPC_SISIPU) then
		-- fsh30010: Sisipu and the bucket of feed.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010", 1);
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(ITEM_BARREL_FEED, 1, 1);
		quest:StartSequence(SEQ_010);
	elseif (seq == SEQ_010 and npcClassId == ENPC_RERENASU) then
		-- Across to the Barrel? (1 = yes) Then fsh30020 (feeding, the
		-- stranger and his dance) and fsh30025 (off to Ul'dah), both ending
		-- on an after-warp fade.
		local go = callClientFunction(player, "delegateEvent", player, quest, "processEvent010_1001");
		if (go == 1) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
			callClientFunction(player, "delegateEvent", player, quest, "processEvent025");
			player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(ITEM_BARREL_FEED, 1);
			quest:StartSequence(SEQ_028);
			player:EndEvent();
			warpTo(player, DOCK_SPOT);
			return;
		end
	elseif (seq == SEQ_028 and npcClassId == ENPC_ROROJARU) then
		-- Rorojaru and the outfit.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent028");
		quest:StartSequence(SEQ_029);
	elseif (seq == SEQ_029 and npcClassId == ENPC_RERENASU) then
		-- Back to the Barrel: the dance (fsh30030), the catch (fsh30040)
		-- and the stranger's farewell (fsh30050, after-warp fade).
		local go = callClientFunction(player, "delegateEvent", player, quest, "processEvent010_1001");
		if (go == 1) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
			callClientFunction(player, "delegateEvent", player, quest, "processEvent040");
			callClientFunction(player, "delegateEvent", player, quest, "processEvent050");
			quest:StartSequence(SEQ_050);
			player:EndEvent();
			warpTo(player, GUILD_SPOT);
			return;
		end
	elseif (seq == SEQ_050 and npcClassId == ENPC_SISIPU) then
		-- fsh30060: Sisipu hears where you went, and storms off.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent060");
		quest:StartSequence(SEQ_060);
	elseif (seq == SEQ_060 and npcClassId == ENPC_SISIPU) then
		-- Use the Echo? (fsh30070: the stranger was the netmaster.)
		local echo = callClientFunction(player, "delegateEvent", player, quest, "processEvent070");
		if (echo == 1) then
			quest:StartSequence(SEQ_070);
		end
	elseif (seq == SEQ_070 and npcClassId == ENPC_NNMULIKA) then
		-- N'nmulika's apology, and payment.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent075");
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
	[SEQ_000] = 11050101; -- fsh30010
	[SEQ_010] = 11050102; -- fsh30020
	[SEQ_029] = 11050104; -- fsh30030
	[SEQ_050] = 11050107; -- fsh30060
	[SEQ_060] = 11050108; -- fsh30070
};

function getJournalMapMarkerList(player, quest)
	return MARKERS[quest:getSequence()];
end
