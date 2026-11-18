require ("global")
require ("quest")

--[[

Quest Script

Name:	Runaway Little Girl
Code:	Min306
Id:	110462
Prereq: Level 36, Miner, Min300

Nenekko has gone missing and the twins are turning Ul'dah upside down.
Linette sends you to Momodi at the Quicksand, where Nenekko finds you
first: she has run away and wants to travel with you, and flees when her
brothers come in (min30610). You find her where the mirage of Sil'dih
shows on the horizon south of the city (min30620); she asks you to see
her to the ferry docks at Vesper Bay. At the docks the sea settles her
mind: she will go home and write Sil'dih's history, and you call her
brothers (min30630). Back at the Concern the twins thank you (min30640):
36,000 gil and 3,600 experience.

The escort west, with the pits you dig to lose her pursuer, is left out:
the mirage spot and the docks are push circles, and the docks' scene
follows the mirage directly. Nenekko's lines at the docks after the
linkpearl call (processEvent035) have no actor to hang on.

Journal: steps 189-194 of the Ul'dah quest journal sheet (0B/45/08/4E).

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Ask Momodi at the Quicksand.
SEQ_010	= 10;  -- Find Nenekko where Sil'dih can be seen.
SEQ_020	= 20;  -- See Nenekko to the ferry docks of Vesper Bay.
SEQ_040	= 40;  -- Return to Linette.

-- Actor Class Ids
ENPC_LINETTE		= 1000861;
ENPC_MOMODI			= 1000841;
ENPC_MIRAGE_CIRCLE	= 1091184; -- where the mirage of Sil'dih is seen
ENPC_DOCKS_CIRCLE	= 1091185; -- the ferry docks of Vesper Bay
-- Miners at the Concern
ENPC_MOHTFRYD		= 1001170;
ENPC_PIERRIQUET		= 1001169;
ENPC_YUYUBESU		= 1001166;
ENPC_CHACHAI		= 1001167;
ENPC_FIFILO			= 1001168;
ENPC_MUMUKIYA		= 1001165;
ENPC_QHOTA_NBOLO	= 1001171;

REWARD_GIL	= 36000;
REWARD_EXP	= 3600;

-- min30630 ends on an after-warp fade at the docks (its cut track).
DOCKS_ZONE = 172;
DOCKS = { -2207.0, 13.97, -420.0, 1.57 };

-- Map markers (client marker block 11046201): each points at the next
-- cutscene.
MARKERS = {
	[SEQ_000] = 11046201;
	[SEQ_010] = 11046202;
	[SEQ_020] = 11046203;
	[SEQ_040] = 11046204;
};

-- What people say between steps. The client script names no speaker;
-- the miners keep the same slots as in Min200.
TALKS = {
	[SEQ_000] = {
		[ENPC_MOHTFRYD] = "processEvent007_2",
		[ENPC_PIERRIQUET] = "processEvent007_3",
		[ENPC_YUYUBESU] = "processEvent007_4",
		[ENPC_CHACHAI] = "processEvent007_5",
		[ENPC_FIFILO] = "processEvent007_6",
		[ENPC_MUMUKIYA] = "processEvent007_7",
		[ENPC_QHOTA_NBOLO] = "processEvent007_8",
	},
	[SEQ_010] = {
		[ENPC_MOMODI] = "processEvent013_2",
	},
	[SEQ_020] = {
		[ENPC_MOMODI] = "processEvent013_2",
	},
	[SEQ_040] = {
		[ENPC_MOHTFRYD] = "processEvent035_3",
		[ENPC_PIERRIQUET] = "processEvent035_4",
		[ENPC_YUYUBESU] = "processEvent035_5",
		[ENPC_CHACHAI] = "processEvent035_6",
		[ENPC_FIFILO] = "processEvent035_7",
		[ENPC_MUMUKIYA] = "processEvent035_8",
	},
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_LINETTE, QFLAG_TALK);
		return;
	end
	if (TALKS[sequence] ~= nil) then
		for classId, _ in pairs(TALKS[sequence]) do
			quest:SetENpc(classId);
		end
	end
	if (sequence == SEQ_000) then
		quest:SetENpc(ENPC_MOMODI, QFLAG_TALK);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_MIRAGE_CIRCLE, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(ENPC_DOCKS_CIRCLE, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_040) then
		quest:SetENpc(ENPC_LINETTE, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_LINETTE) then
		-- Help find Nenekko (1 = accepted).
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventLinetteStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and npcClassId == ENPC_MOMODI) then
		-- Momodi, then min30610: Nenekko at the Quicksand.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent013");
		quest:StartSequence(SEQ_010);
	elseif (seq == SEQ_040 and npcClassId == ENPC_LINETTE) then
		-- min30640: the twins' thanks, and payment.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent040");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 2);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddGil(REWARD_GIL);
		player:CompleteQuest(quest);
		player:EndEvent();
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

	if (npcClassId == ENPC_MIRAGE_CIRCLE and seq == SEQ_010) then
		-- min30620: Nenekko by the mirage asks to be taken to the docks.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		quest:StartSequence(SEQ_020);
	elseif (npcClassId == ENPC_DOCKS_CIRCLE and seq == SEQ_020) then
		-- min30630: the sea, the shard, and the call to her brothers.
		-- After-warp fade.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
		quest:StartSequence(SEQ_040);
		player:EndEvent();
		GetWorldManager():DoZoneChange(player, DOCKS_ZONE, nil, 0, 15, DOCKS[1], DOCKS[2], DOCKS[3], DOCKS[4]);
		return;
	end
	player:EndEvent();
end

function getJournalMapMarkerList(player, quest)
	return MARKERS[quest:GetSequence()];
end
