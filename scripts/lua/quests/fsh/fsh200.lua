require ("global")
require ("quest")

--[[

Quest Script

Name:	To Fight a Fishback
Code:	Fsh200
Id:	110500
Prereq: Level 20, Fisher

N'nmulika welcomes you to Wawalago's Pullers and sends you to Maisie for
your first job. Maisie (fsh20010) explains how the Knights of the Barracuda
and the pirates lure the Sahagin out with pixie remoras, and sends you to
fish some up off the cliffs of lowland La Noscea. Bring them back to her
(fsh20020) for 20,000 gil and 2,000 experience.

The remora is a quest-only catch: our fishing point 9140 on the Lower La
Noscea shore (server_gather_node_quests) shows only on SEQ_010 and yields
it; it is checked in the bag as it comes off the line.

Journal: steps 43, 44 and 118 of the quest journal sheet (0B/45/08/1B).

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Find Maisie in the guild.
SEQ_010	= 10;  -- Fish up pixie remoras for Maisie.

-- Actor Class Ids
ENPC_NNMULIKA		= 1000153;
ENPC_MAISIE			= 1000173;
ENPC_ZONGGO			= 1000057;
ENPC_ASTRID			= 1000180;
ENPC_XAVALIEN		= 1000181;
ENPC_CLIFTON		= 1000199;
ENPC_UNDSATZ		= 1000200;
ENPC_RERENASU		= 1000201;
ENPC_DACA_JINJAHL	= 1000202;
ENPC_BLOEMERL		= 1000203;
ENPC_SKOEFMYND		= 1000662;

ITEM_PIXIE_REMORA	= 11000127;

REWARD_GIL	= 20000;
REWARD_EXP	= 2000;

-- The pullers' word for a new hand. The client script names no speaker;
-- these follow the lines' content (Clifton fishes from the cliffs; Daca
-- Jinjahl speaks to Bloemerl, who answers).
TALKS = {
	[ENPC_NNMULIKA] = "processEvent005_2",
	[ENPC_ASTRID] = "processEvent010_2",
	[ENPC_XAVALIEN] = "processEvent010_3",
	[ENPC_ZONGGO] = "processEvent010_4",
	[ENPC_CLIFTON] = "processEvent010_5",
	[ENPC_DACA_JINJAHL] = "processEvent010_6",
	[ENPC_BLOEMERL] = "processEvent010_7",
	[ENPC_SKOEFMYND] = "processEvent010_8",
	[ENPC_UNDSATZ] = "processEvent010_10",
	[ENPC_RERENASU] = "processEvent010_11",
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
	for classId, _ in pairs(TALKS) do
		quest:SetENpc(classId);
	end
	if (sequence == SEQ_000) then
		quest:SetENpc(ENPC_MAISIE, QFLAG_TALK);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_MAISIE, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_NNMULIKA) then
		-- Join the pullers (1 = accepted).
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventNnmulikaStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and npcClassId == ENPC_MAISIE) then
		-- fsh20010: Maisie, the Sahagin, and the remoras they crave.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		quest:StartSequence(SEQ_010);
	elseif (seq == SEQ_010 and npcClassId == ENPC_MAISIE) then
		if (player:GetItemPackage(INVENTORY_NORMAL):HasItem(ITEM_PIXIE_REMORA, 1)) then
			-- fsh20020: a full pack, and payment.
			player:GetItemPackage(INVENTORY_NORMAL):RemoveItem(ITEM_PIXIE_REMORA, 1);
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 2);
			player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
			player:AddGil(REWARD_GIL);
			player:CompleteQuest(quest);
		else
			-- Where to find them, and how many.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010_9");
		end
	elseif (TALKS[npcClassId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, TALKS[npcClassId]);
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
	[SEQ_000] = 11050001; -- fsh20010
	[SEQ_010] = 11050002; -- fsh20020
};

function getJournalMapMarkerList(player, quest)
	return MARKERS[quest:getSequence()];
end
