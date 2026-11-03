require ("global")
require ("quest")
require ("modifiers")

--[[

Quest Script

Name:	Unalienable Rights
Code:	Gla300
Id:	110081
Prereq: Level 30, Gladiator, Gla200

The Coliseum wants new blood. Lulutsu sends you to Gridania after the
guild's matchmaker Yoyobina (gla30010), who finds you at Carline Canopy
(gla30020) and sends you to the Wailing Barracks. The Wood Wailers answer
with a friendly spar (processEvent025, gla30030) against the lancer
J'moldva (content Gla30001). After the bout (gla30040) the Echo on
J'moldva (gla30050) shows who she was, and Yoyobina, waiting in the
Barracks, calls you home (processEvent055). In the Coliseum Lulutsu hears
it (gla30060); the Echo on Yoyobina (processEvent065) takes you into the
past Coliseum for J'moldva's last match (gla30070), and the past Yoyobina
(gla30080) brings you back. Lulutsu (processEvent090) pays 30,000 gil and
3,000 experience.

Yoyobina's Gridania body (1001076, seed 296) stands in the Barracks and in
the past Coliseum (PrivateAreaMasterPast 5, shared with man0u1).

]]

-- Sequence Numbers
SEQ_010	= 10;  -- Travel to Gridania and ask around at Carline Canopy.
SEQ_020	= 20;  -- Visit the Wailing Barracks.
SEQ_030	= 30;  -- Defeat the lancer J'moldva.
SEQ_040	= 40;  -- Use the Echo on J'moldva.
SEQ_050	= 50;  -- Speak with Yoyobina.
SEQ_055	= 55;  -- Return to the Coliseum.
SEQ_060	= 60;  -- Use the Echo on Yoyobina.
SEQ_070	= 70;  -- Find Yoyobina in the past.
SEQ_080	= 80;  -- Lulutsu has your reward.

-- Actor Class Ids
ENPC_LULUTSU		= 1000863;
ENPC_COYNACH		= 1000631;
ENPC_LYNGWAEK		= 1000647;
ENPC_JAJANZO		= 1000654;
ENPC_UBOKHN			= 1000668;
ENPC_YOYOBINA		= 1000927;
ENPC_SINGLETON		= 1001445;
ENPC_VANNES			= 1001464;
ENPC_TATASHA		= 1001465;
ENPC_MIOUNNE		= 1000230;
ENPC_JMOLDVA		= 1000599;
ENPC_YOYOBINA_AWAY	= 1001076; -- seed 296: in the Barracks and the past Coliseum
ENPC_WILLELDA		= 1000242;
ENPC_LUITFRID		= 1000568;
ENPC_DHEMDAEG		= 1000567;
ENPC_BURCHARD		= 1000243;
ENPC_NUALA			= 1000681;
ENPC_AERSTSYN		= 1000627;

-- Quest Markers (each names its scene in the client's marker index)
MRKR_LULUTSU		= 11008101;
MRKR_CANOPY			= 11008102;
MRKR_BARRACKS		= 11008103;
MRKR_AFTER_BOUT		= 11008104;
MRKR_JMOLDVA		= 11008105;
MRKR_COLISEUM		= 11008106;
MRKR_PAST_COLISEUM	= 11008107;
MRKR_PAST_YOYOBINA	= 11008108;

REWARD_GIL	= 30000;
REWARD_EXP	= 3000;

-- The Barracks courtyard (gla30030/40 actor tracks; Gridania cut + (32, 12,
-- -1312)): where the bout is fought and where you are set down after it.
BOUT_SPOT = { 185.0, 27.5, -1586.0, 1.57 };
BARRACKS_AFTER = { 183.0, 27.5, -1586.0, 1.57 };
-- In front of the guild counter (Gla200's walked spot).
GUILD_HALL = { -190.5, 195.0, 184.5, 3.0 };
-- The past Coliseum (man0u1's arrival spot in PrivateAreaMasterPast 5).
PAST_HALL = { -185.0, 195.0, 185.0, -2.3 };
PAST_AREA = 5;

-- What people say between steps. The client script names no speaker; these
-- follow the lines' content and where each step stands.
TALKS = {
	[SEQ_010] = {
		[ENPC_LULUTSU] = "processEvent010_2",
		[ENPC_JAJANZO] = "processEvent010_3",
		[ENPC_COYNACH] = "processEvent010_4",
		[ENPC_SINGLETON] = "processEvent010_5",
		[ENPC_LYNGWAEK] = "processEvent010_6",
		[ENPC_VANNES] = "processEvent010_7",
		[ENPC_TATASHA] = "processEvent010_8",
		[ENPC_UBOKHN] = "processEvent010_9",
	},
	[SEQ_020] = {
		[ENPC_MIOUNNE] = "processEvent020_3",
		[ENPC_LUITFRID] = "processEvent020_2",
		[ENPC_DHEMDAEG] = "processEvent020_5",
		[ENPC_BURCHARD] = "processEvent020_6",
	},
	[SEQ_040] = {
		[ENPC_LUITFRID] = "processEvent040_2",
		[ENPC_DHEMDAEG] = "processEvent040_3",
		[ENPC_BURCHARD] = "processEvent040_4",
		[ENPC_NUALA] = "processEvent040_5",
		[ENPC_AERSTSYN] = "processEvent040_6",
		[ENPC_WILLELDA] = "processEvent040_7",
	},
	[SEQ_060] = {
		[ENPC_LULUTSU] = "processEvent060_2",
	},
	[SEQ_080] = {
		[ENPC_YOYOBINA] = "processEvent080_2",
		[ENPC_JAJANZO] = "processEvent080_3",
		[ENPC_COYNACH] = "processEvent080_4",
		[ENPC_SINGLETON] = "processEvent080_5",
		[ENPC_LYNGWAEK] = "processEvent080_6",
		[ENPC_VANNES] = "processEvent080_7",
		[ENPC_TATASHA] = "processEvent080_8",
		[ENPC_UBOKHN] = "processEvent080_9",
	},
};

function onStart(player, quest)
	quest:StartSequence(SEQ_010);
end

function onFinish(player, quest)
end

local function setTalkers(quest, sequence)
	if (TALKS[sequence] ~= nil) then
		for classId, _ in pairs(TALKS[sequence]) do
			quest:SetENpc(classId);
		end
	end
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_LULUTSU, QFLAG_TALK);
		return;
	end
	setTalkers(quest, sequence);
	if (sequence == SEQ_010) then
		quest:SetENpc(ENPC_MIOUNNE, QFLAG_TALK);
	elseif (sequence == SEQ_020 or sequence == SEQ_030) then
		-- SEQ_030 keeps her open: a lost or abandoned bout is retried.
		quest:SetENpc(ENPC_JMOLDVA, QFLAG_TALK);
	elseif (sequence == SEQ_040) then
		-- Stays open: declining the Echo leaves her waiting.
		quest:SetENpc(ENPC_JMOLDVA, QFLAG_TALK);
	elseif (sequence == SEQ_050) then
		quest:SetENpc(ENPC_YOYOBINA_AWAY, QFLAG_TALK);
	elseif (sequence == SEQ_055) then
		quest:SetENpc(ENPC_LULUTSU, QFLAG_TALK);
	elseif (sequence == SEQ_060) then
		quest:SetENpc(ENPC_YOYOBINA, QFLAG_TALK);
	elseif (sequence == SEQ_070) then
		-- The present Yoyobina sends you back if you left the past early.
		quest:SetENpc(ENPC_YOYOBINA_AWAY, QFLAG_TALK);
		quest:SetENpc(ENPC_YOYOBINA, QFLAG_TALK);
	elseif (sequence == SEQ_080) then
		quest:SetENpc(ENPC_LULUTSU, QFLAG_REWARD);
	end
end

local function warpTo(player, zoneId, spot)
	GetWorldManager():DoZoneChange(player, zoneId, nil, 0, 15, spot[1], spot[2], spot[3], spot[4]);
end

local function warpToPast(player)
	GetWorldManager():DoZoneChange(player, 209, "PrivateAreaMasterPast", PAST_AREA, 15, PAST_HALL[1], PAST_HALL[2], PAST_HALL[3], PAST_HALL[4]);
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_LULUTSU) then
		-- gla30010: the Coliseum's call for new blood (1 = accepted).
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventLulutsuStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_010 and npcClassId == ENPC_MIOUNNE) then
		-- gla30020: Yoyobina finds you at Carline Canopy.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		quest:StartSequence(SEQ_020);
	elseif ((seq == SEQ_020 or seq == SEQ_030) and npcClassId == ENPC_JMOLDVA) then
		-- The Wood Wailers' offer of a spar (1 = yes), then gla30030, which
		-- ends on an after-warp fade that the move into the bout lifts.
		local spar = callClientFunction(player, "delegateEvent", player, quest, "processEvent025");
		if (spar == 1) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
			if (seq == SEQ_020) then
				quest:StartSequence(SEQ_030);
			end
			startGla300Bout(player, quest);
			return;
		end
	elseif (seq == SEQ_040 and npcClassId == ENPC_JMOLDVA) then
		-- The Echo on J'moldva: 1 plays gla30050, 0 leaves her waiting.
		local echo = callClientFunction(player, "delegateEvent", player, quest, "processEvent050");
		if (echo == 1) then
			quest:StartSequence(SEQ_050);
		end
	elseif (seq == SEQ_050 and npcClassId == ENPC_YOYOBINA_AWAY) then
		-- Yoyobina calls it a day in Gridania.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent055");
		quest:StartSequence(SEQ_055);
	elseif (seq == SEQ_055 and npcClassId == ENPC_LULUTSU) then
		-- gla30060: refused again. It ends on an after-warp fade.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent060");
		quest:StartSequence(SEQ_060);
		player:EndEvent();
		warpTo(player, 209, GUILD_HALL);
		return;
	elseif (seq == SEQ_060 and npcClassId == ENPC_YOYOBINA) then
		-- The Echo on Yoyobina: 1 moves you into the past, where gla30070
		-- (after-warp) opens J'moldva's last match; 0 leaves him waiting.
		local echo = callClientFunction(player, "delegateEvent", player, quest, "processEvent065");
		if (echo == 1) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent070");
			quest:StartSequence(SEQ_070);
			player:EndEvent();
			warpToPast(player);
			return;
		end
	elseif (seq == SEQ_070 and npcClassId == ENPC_YOYOBINA) then
		-- Left the past before the match ended: straight back in.
		player:EndEvent();
		warpToPast(player);
		return;
	elseif (seq == SEQ_070 and npcClassId == ENPC_YOYOBINA_AWAY) then
		-- gla30080: the end of the match, and Yoyobina back in the present.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent080");
		quest:StartSequence(SEQ_080);
		player:EndEvent();
		warpTo(player, 209, GUILD_HALL);
		return;
	elseif (seq == SEQ_080 and npcClassId == ENPC_LULUTSU) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent090");
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

function startGla300Bout(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Gla30001", "SimpleContentGla30001", "Quest/QuestDirectorGla30001", 206);
	if (contentArea == nil) then
		player:EndEvent();
		warpTo(player, 206, BARRACKS_AFTER);
		return;
	end
	local director = contentArea:GetContentDirector();
	player:AddDirector(director);
	director:StartDirector(false);
	player:KickEvent(director, "noticeEvent", true);
	player:SetLoginDirector(director);
	player:EndEvent();
	GetWorldManager():DoZoneChangeContent(player, contentArea, BOUT_SPOT[1], BOUT_SPOT[2], BOUT_SPOT[3], BOUT_SPOT[4], 16);
end

-- QuestDirectorGla30001, once J'moldva yields (a loss never signals the
-- director).
function finishGla300Bout(player, quest, actor)
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	-- gla30040: "Enough!" It ends on an after-warp fade.
	callClientFunction(player, "delegateEvent", player, quest, "processEvent040");
	quest:StartSequence(SEQ_040);
	player:EndEvent();
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	warpTo(player, 206, BARRACKS_AFTER);
end

-- SimpleContentGla30001, on a loss (pinned at 1 HP, or out of time): set
-- down in the courtyard to ask for another bout.
function loseGla300Bout(player, timedOut)
	if (timedOut) then
		player:SendMessage(0x20, "", "Time has run out.");
	else
		player:SendMessage(0x20, "", "You are defeated.");
	end
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	warpTo(player, 206, BARRACKS_AFTER);
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_010) then
		return MRKR_CANOPY;
	elseif (seq == SEQ_020 or seq == SEQ_030) then
		return MRKR_BARRACKS;
	elseif (seq == SEQ_040) then
		return MRKR_JMOLDVA;
	elseif (seq == SEQ_050) then
		return MRKR_AFTER_BOUT;
	elseif (seq == SEQ_055) then
		return MRKR_COLISEUM;
	elseif (seq == SEQ_060) then
		return MRKR_PAST_COLISEUM;
	elseif (seq == SEQ_070) then
		return MRKR_PAST_YOYOBINA;
	elseif (seq == SEQ_080) then
		return MRKR_LULUTSU;
	end
end
