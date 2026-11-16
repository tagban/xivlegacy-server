require ("global")
require ("quest")

--[[

Quest Script

Name:	Gridanian Roots
Code:	Hrv200
Id:	110480
Prereq: Level 20, Botanist

Opyltyl welcomes you to the Greatloam Growery and sends you to Cicely to
pay your respects to the wood (processEventOpyltylStart, 1 = accepted).
Cicely marks a patch of weeds by Quarrymill and stays behind (hrv20010).
At Quarrymill you clear the weeds; Cicely turns up, grumbles about life in
Gridania and leaves, and a moogle tells you how gifted she really is
(hrv20020, a push circle). Back at the Growery Opyltyl hears how it went
and pays you (hrv20030): 20,000 gil and 2,000 experience, like the other
level-20 guild quests (the client's reward table has no row for it).

Journal: steps 13-15 of the quest journal sheet.

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Speak with Cicely.
SEQ_010	= 10;  -- Clear the weeds by Quarrymill.
SEQ_020	= 20;  -- Report to Opyltyl.

-- Actor Class Ids
ENPC_ONGUEN		= 1000074;
ENPC_OPYLTYL	= 1000236;
ENPC_CICELY		= 1000326;
ENPC_EBURHART	= 1000629;
ENPC_VNABYANO	= 1001101;
ENPC_QUARRYMILL	= 1091120; -- push circle on the weed patch

-- Quest Markers (each names its scene in the client's marker index)
MRKR_CICELY		= 11048001;
MRKR_QUARRYMILL	= 11048002;
MRKR_OPYLTYL	= 11048003;

REWARD_GIL	= 20000;
REWARD_EXP	= 2000;

-- Both scenes that end on an after-warp fade set you down here.
-- South Shroud, next to the weed patch (height from the client's ground mesh).
QUARRYMILL_ZONE = 154;
QUARRYMILL = { 1443.0, -12.5, 916.0, 0.9 };
-- The Greatloam Growery, in front of Opyltyl.
GROWERY_ZONE = 206;
GROWERY = { -205.6, 20.0, -1457.5, -0.06 };

-- What the botanists say between steps. The client script names no
-- speaker; these follow the lines' content.
TALKS = {
	[SEQ_000] = {
		[ENPC_OPYLTYL] = "processEvent005_2",
		[ENPC_ONGUEN] = "processEvent005_3",
		[ENPC_EBURHART] = "processEvent005_4",
		[ENPC_VNABYANO] = "processEvent005_5",
	},
	[SEQ_010] = {
		[ENPC_CICELY] = "processEvent010_2",
		[ENPC_OPYLTYL] = "processEvent010_3",
	},
	[SEQ_020] = {
		[ENPC_ONGUEN] = "processEvent020_2",
		[ENPC_VNABYANO] = "processEvent020_3",
		[ENPC_EBURHART] = "processEvent020_4",
	},
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_OPYLTYL, QFLAG_TALK);
		return;
	end
	if (TALKS[sequence] ~= nil) then
		for classId, _ in pairs(TALKS[sequence]) do
			quest:SetENpc(classId);
		end
	end
	if (sequence == SEQ_000) then
		quest:SetENpc(ENPC_CICELY, QFLAG_TALK);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_QUARRYMILL, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(ENPC_OPYLTYL, QFLAG_REWARD);
	end
end

local function warpTo(player, zoneId, spot)
	GetWorldManager():DoZoneChange(player, zoneId, nil, 0, 15, spot[1], spot[2], spot[3], spot[4]);
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_OPYLTYL) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventOpyltylStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and npcClassId == ENPC_CICELY) then
		-- hrv20010: Cicely marks the weeds and stays behind.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		quest:StartSequence(SEQ_010);
	elseif (seq == SEQ_020 and npcClassId == ENPC_OPYLTYL) then
		-- hrv20030: the report, and payment. It ends on an after-warp fade.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 2);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddGil(REWARD_GIL);
		player:CompleteQuest(quest);
		player:EndEvent();
		warpTo(player, GROWERY_ZONE, GROWERY);
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

	if (npcClassId == ENPC_QUARRYMILL and seq == SEQ_010) then
		-- hrv20020: the weeds cleared, Cicely and the moogle. It ends on an
		-- after-warp fade.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		quest:StartSequence(SEQ_020);
		player:EndEvent();
		warpTo(player, QUARRYMILL_ZONE, QUARRYMILL);
		return;
	end
	player:EndEvent();
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_000) then
		return MRKR_CICELY;
	elseif (seq == SEQ_010) then
		return MRKR_QUARRYMILL;
	elseif (seq == SEQ_020) then
		return MRKR_OPYLTYL;
	end
end
