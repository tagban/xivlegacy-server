require ("global")
require ("quest")

--[[

Quest Script

Name:	Little Saboteurs
Code:	Min300
Id:	110461
Prereq: Level 30, Miner, Min200

The twins have gone to Gridania without you. Linette sends you after
them; at the Roost they are tormenting the innkeeper and put you to work
(min30010): ask the coachman at the chocobo stables where Fafajon, Nenekko's
suitor, hired a carriage to. He lets slip the flower fields near Longroot;
the twins meet you there and dig up Fafajon's buried box (min30020) and
send you back to keep Nenekko in Ul'dah. Linette has heard she is shopping
at Eshtaime's Lapidaries; you overhear her mother and talk with Nenekko
(min30030, min30040). Back at the Concern her mother warns you off and
scolds the twins (min30050); the Echo on each twin shows what they put in
the box (min30060, min30070). 30,000 gil and 3,000 experience.

The coachman's parley is left out, and so is the linkpearl call to the
twins: his scene leads straight to the clearing. The clearing east of
Camp Tranquil and the Lapidaries' door are push circles; Nenekko only
stood in an instance of the Lapidaries. The twins get public spawns at
the Concern for the Echo, and the coachman one at the Gridania stables.

Journal: steps 179-188 of the Ul'dah quest journal sheet (0B/45/08/4E).

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Find the twins at the Roost.
SEQ_010	= 10;  -- Question the coachman at the chocobo stables.
SEQ_017	= 17;  -- Meet the twins at the flower fields near Longroot.
SEQ_025	= 25;  -- Return to Linette.
SEQ_030	= 30;  -- Find Nenekko at Eshtaime's Lapidaries.
SEQ_045	= 45;  -- Return to Linette.
SEQ_050	= 50;  -- Use the Echo on the twins.

-- Actor Class Ids
ENPC_LINETTE		= 1000861;
ENPC_VKOROLON		= 1000458;
ENPC_COACHMAN		= 1000703;
ENPC_POPOKKULI		= 1000040;
ENPC_SESERUKKA		= 1000041;
ENPC_FIELD_CIRCLE	= 1091182; -- the flower fields east of Camp Tranquil
ENPC_LAPIDARIES_CIRCLE	= 1091183; -- Eshtaime's Lapidaries
-- Miners at the Concern
ENPC_MOHTFRYD		= 1001170;
ENPC_PIERRIQUET		= 1001169;
ENPC_YUYUBESU		= 1001166;
ENPC_CHACHAI		= 1001167;
ENPC_FIFILO			= 1001168;
ENPC_MUMUKIYA		= 1001165;
ENPC_QHOTA_NBOLO	= 1001171;

-- One Echo per twin; the last one pays.
FLAG_ECHO_POPOKKULI = 0;
FLAG_ECHO_SESERUKKA = 1;
ECHOES = {
	[ENPC_POPOKKULI] = { flag = FLAG_ECHO_POPOKKULI, event = "processEvent060", after = "processEvent050_2" },
	[ENPC_SESERUKKA] = { flag = FLAG_ECHO_SESERUKKA, event = "processEvent070", after = "processEvent050_3" },
};

REWARD_GIL	= 30000;
REWARD_EXP	= 3000;

-- Scenes that end on an after-warp fade set you down here.
-- The clearing (min30020 cut track).
FIELD_ZONE = 154;
FIELD = { 1500.0, -0.1, 1317.0, 0.0 };
-- Inside the Lapidaries, by Elecotte (min30040).
ULDAH_ZONE = 209;
LAPIDARIES = { -130.8, 201.6, 258.8, -2.77 };
-- The Concern, in front of Linette (min30050, the last Echo).
CONCERN = { -94.9, 195.6, 313.8, 1.71 };

-- Map markers (client marker block 11046101): each points at the next
-- cutscene.
MARKERS = {
	[SEQ_000] = { 11046101 };
	[SEQ_017] = { 11046102 };
	[SEQ_030] = { 11046103, 11046104 };
	[SEQ_045] = { 11046105 };
	[SEQ_050] = { 11046106, 11046107 };
};

-- What people say between steps. The client script names no speaker;
-- the miners keep the same slots as in Min200.
TALKS = {
	[SEQ_000] = {
		[ENPC_LINETTE] = "processEvent005_2",
		[ENPC_MOHTFRYD] = "processEvent005_3",
		[ENPC_PIERRIQUET] = "processEvent005_4",
		[ENPC_YUYUBESU] = "processEvent005_5",
		[ENPC_CHACHAI] = "processEvent005_6",
		[ENPC_FIFILO] = "processEvent005_7",
		[ENPC_MUMUKIYA] = "processEvent005_8",
	},
	[SEQ_010] = {
		[ENPC_VKOROLON] = "processEvent010_8",
		[ENPC_LINETTE] = "processEvent010_2",
		[ENPC_MOHTFRYD] = "processEvent010_3",
		[ENPC_PIERRIQUET] = "processEvent010_4",
		[ENPC_YUYUBESU] = "processEvent010_5",
	},
	[SEQ_017] = {
		[ENPC_VKOROLON] = "processEvent013_2",
	},
	[SEQ_025] = {
		[ENPC_MOHTFRYD] = "processEvent020_2",
		[ENPC_PIERRIQUET] = "processEvent020_3",
	},
	[SEQ_030] = {
		[ENPC_LINETTE] = "processEvent025_2",
	},
	[SEQ_045] = {
		[ENPC_MOHTFRYD] = "processEvent040_2",
		[ENPC_PIERRIQUET] = "processEvent040_3",
		[ENPC_YUYUBESU] = "processEvent040_4",
		[ENPC_CHACHAI] = "processEvent040_5",
		[ENPC_FIFILO] = "processEvent040_6",
		[ENPC_QHOTA_NBOLO] = "processEvent040_7",
	},
	[SEQ_050] = {
		[ENPC_LINETTE] = "processEvent050_4",
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
		quest:SetENpc(ENPC_VKOROLON, QFLAG_TALK);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_COACHMAN, QFLAG_TALK);
	elseif (sequence == SEQ_017) then
		quest:SetENpc(ENPC_FIELD_CIRCLE, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_025 or sequence == SEQ_045) then
		quest:SetENpc(ENPC_LINETTE, QFLAG_TALK);
	elseif (sequence == SEQ_030) then
		quest:SetENpc(ENPC_LAPIDARIES_CIRCLE, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_050) then
		local data = quest:GetData();
		for classId, echo in pairs(ECHOES) do
			quest:SetENpc(classId, data:GetFlag(echo.flag) and QFLAG_OFF or QFLAG_TALK);
		end
	end
end

local function warpTo(player, zone, spot)
	GetWorldManager():DoZoneChange(player, zone, nil, 0, 15, spot[1], spot[2], spot[3], spot[4]);
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();
	local data = quest:GetData();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_LINETTE) then
		-- After the twins in Gridania (1 = accepted).
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventLinetteStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and npcClassId == ENPC_VKOROLON) then
		-- min30010: the twins at the Roost, and the coachman.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		quest:StartSequence(SEQ_010);
	elseif (seq == SEQ_010 and npcClassId == ENPC_COACHMAN) then
		-- The coachman lets slip where Fafajon's carriage went.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent013");
		quest:StartSequence(SEQ_017);
	elseif (seq == SEQ_025 and npcClassId == ENPC_LINETTE) then
		-- Nenekko is shopping at the Lapidaries.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent025");
		quest:StartSequence(SEQ_030);
	elseif (seq == SEQ_045 and npcClassId == ENPC_LINETTE) then
		-- min30050: the lady mother and the twins. After-warp fade.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050");
		quest:StartSequence(SEQ_050);
		player:EndEvent();
		warpTo(player, ULDAH_ZONE, CONCERN);
		return;
	elseif (seq == SEQ_050 and ECHOES[npcClassId] ~= nil) then
		local echo = ECHOES[npcClassId];
		if (data:GetFlag(echo.flag)) then
			callClientFunction(player, "delegateEvent", player, quest, echo.after);
		else
			-- The Echo (1 = look into his past). The second one ends on an
			-- after-warp fade and pays.
			local other = (npcClassId == ENPC_POPOKKULI) and FLAG_ECHO_SESERUKKA or FLAG_ECHO_POPOKKULI;
			local last = data:GetFlag(other);
			local seen = callClientFunction(player, "delegateEvent", player, quest, echo.event, last and 1 or 0);
			if (seen == 1) then
				data:SetFlag(echo.flag);
				quest:SetENpc(npcClassId, QFLAG_OFF);
				if (last) then
					callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 2);
					player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
					player:AddGil(REWARD_GIL);
					player:CompleteQuest(quest);
					player:EndEvent();
					warpTo(player, ULDAH_ZONE, CONCERN);
					return;
				end
			end
		end
	elseif (TALKS[seq] ~= nil and TALKS[seq][npcClassId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, TALKS[seq][npcClassId]);
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (npcClassId == ENPC_FIELD_CIRCLE and seq == SEQ_017) then
		-- min30020: the twins dig up Fafajon's box. After-warp fade.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		quest:StartSequence(SEQ_025);
		player:EndEvent();
		warpTo(player, FIELD_ZONE, FIELD);
		return;
	elseif (npcClassId == ENPC_LAPIDARIES_CIRCLE and seq == SEQ_030) then
		-- min30030 (Nenekko and her mother) and min30040 (Nenekko's
		-- doubts), both after-warp fades.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
		callClientFunction(player, "delegateEvent", player, quest, "processEvent040");
		quest:StartSequence(SEQ_045);
		player:EndEvent();
		warpTo(player, ULDAH_ZONE, LAPIDARIES);
		return;
	end
	player:EndEvent();
end

function getJournalMapMarkerList(player, quest)
	local markers = MARKERS[quest:GetSequence()];
	if (markers == nil) then
		return nil;
	end
	return unpack(markers);
end
