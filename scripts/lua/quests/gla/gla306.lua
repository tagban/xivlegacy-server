require ("global")
require ("quest")
require ("modifiers")

--[[

Quest Script

Name:	Thrill of the Fight
Code:	Gla306
Id:	110082
Prereq: Level 36, Gladiator, Gla300

Your Coliseum debut. Lulutsu calls you to the tourney of warriors;
Yoyobina sends you round the other gladiators (processEvent003) and then
down to the sands (processEvent005, gla30610) to fight an Ala Mhigan
bladedancer (content Gla30601). After the win (gla30620) a Lalafell turns
up: the challenger you beat for the guild in Gla200. The Echo on him
(processEvent024) is a rematch in which he shows his real weapon, an axe
(content Gla30602). Yoyobina hears it (gla30630) and you watch his next
match from the stands (gla30640). The Echo on the beaten Lalafell
(processEvent045) shows the Silver Bazaar, where Yoyobina waives the
Coliseum's fees for Ala Mhigans (gla30650). Lulutsu (processEvent055) pays
36,000 gil and 3,600 experience.

The Lalafell (1000601) and his partners, an Ala Mhigan pikeman and axeman
(1001978/1001979), stand in the guild hall; the Silver Bazaar is
PrivateAreaMasterPast 5 in Western Thanalan, with the pikeman, axeman,
bowman and shaman (1001978-1001981) as refugees and a push circle
(1090517) at the crowd.

Journal: steps 105-115 of the quest journal sheet.

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Seek out Yoyobina.
SEQ_003	= 3;   -- Hear the other gladiators, then speak to Yoyobina again.
SEQ_005	= 5;   -- Your time on the bloodsands has come.
SEQ_010	= 10;  -- The bout is under way (back in the hall: it was lost).
SEQ_020	= 20;  -- A familiar Lalafell; speak to Yoyobina.
SEQ_023	= 23;  -- Use the Echo on the Ala Mhigan challenger.
SEQ_024	= 24;  -- The Echo rematch (back in the hall: it was lost).
SEQ_025	= 25;  -- Report to Yoyobina.
SEQ_030	= 30;  -- Head to the stands.
SEQ_040	= 40;  -- Speak to the beaten Ala Mhigan.
SEQ_045	= 45;  -- The Echo at the Silver Bazaar.
SEQ_050	= 50;  -- Lulutsu has your reward.

-- Actor Class Ids
ENPC_LULUTSU		= 1000863;
ENPC_COYNACH		= 1000631;
ENPC_LYNGWAEK		= 1000647;
ENPC_JAJANZO		= 1000654;
ENPC_UBOKHN			= 1000668;
ENPC_YOYOBINA		= 1000927;
ENPC_QMHALAWI		= 1000969;
ENPC_SINGLETON		= 1001445;
ENPC_VANNES			= 1001464;
ENPC_TATASHA		= 1001465;
ENPC_CHALLENGER		= 1000601; -- the Lalafell
ENPC_PIKEMAN		= 1001978; -- his partners in the hall; refugees in the Echo
ENPC_AXEMAN			= 1001979;
ENPC_BOWMAN			= 1001980; -- refugees in the Echo
ENPC_SHAMAN			= 1001981;
ENPC_ARENA_DOORS	= 1090500; -- Gla200's push circle at the doors behind Yoyobina
ENPC_BAZAAR_CROWD	= 1090517; -- push circle at the crowd in the Silver Bazaar

-- Quest Markers (each names its scene in the client's marker index)
MRKR_BOUT			= 11008201;
MRKR_LOST			= 11008202;
MRKR_YOYOBINA		= 11008203;
MRKR_REPORT			= 11008204;
MRKR_STANDS			= 11008205;
MRKR_BAZAAR			= 11008206;
MRKR_LULUTSU		= 11008101; -- Gla300's; Gla306 has none of its own for her

REWARD_GIL	= 36000;
REWARD_EXP	= 3600;

-- Where the bouts are fought (Gla200's walked arena spot) and where you are
-- set down afterwards, in front of the guild counter.
ARENA = { -209.9, 192.0, 146.4, 0.8 };
GUILD_HALL = { -190.5, 195.0, 184.5, 3.0 };
-- The Silver Bazaar (gla30650's tracks are Western Thanalan world
-- coordinates): where the Echo sets you down, short of the crowd.
BAZAAR_ZONE = 172;
BAZAAR_AREA = 5;
BAZAAR_ARRIVAL = { -1345.0, 55.6, 501.0, 2.5 };

-- What people say between steps. The client script names no speaker; these
-- follow the lines' content and where each step stands.
TALKS_BEFORE_BOUT = {
	[ENPC_LULUTSU] = "processEvent003_2",
	[ENPC_JAJANZO] = "processEvent003_3",
	[ENPC_SINGLETON] = "processEvent003_4",
	[ENPC_LYNGWAEK] = "processEvent003_5",
	[ENPC_TATASHA] = "processEvent003_6",
	[ENPC_VANNES] = "processEvent003_7",
	[ENPC_UBOKHN] = "processEvent003_8",
	[ENPC_QMHALAWI] = "processEvent003_9",
	[ENPC_COYNACH] = "processEvent003_10", -- repair and buy: the guild shop
};
TALKS = {
	[SEQ_000] = {
		[ENPC_LULUTSU] = "processEvent000_1",
	},
	[SEQ_003] = TALKS_BEFORE_BOUT,
	[SEQ_005] = TALKS_BEFORE_BOUT,
	[SEQ_010] = {
		-- After a lost bout.
		[ENPC_COYNACH] = "processEvent003_11",
		[ENPC_LULUTSU] = "processEvent003_12",
	},
	[SEQ_020] = {
		[ENPC_PIKEMAN] = "processEvent020_2",
		[ENPC_AXEMAN] = "processEvent020_3",
		[ENPC_CHALLENGER] = "processEvent020_4",
	},
	[SEQ_023] = {
		[ENPC_PIKEMAN] = "processEvent020_2",
		[ENPC_AXEMAN] = "processEvent020_3",
		[ENPC_YOYOBINA] = "processEvent023_2",
	},
	[SEQ_024] = {
		[ENPC_PIKEMAN] = "processEvent020_2",
		[ENPC_AXEMAN] = "processEvent020_3",
		[ENPC_YOYOBINA] = "processEvent023_2",
	},
	[SEQ_040] = {
		[ENPC_YOYOBINA] = "processEvent040_2",
	},
	[SEQ_045] = {
		[ENPC_PIKEMAN] = "processEvent045_2",
		[ENPC_AXEMAN] = "processEvent045_3",
		[ENPC_BOWMAN] = "processEvent045_4",
		[ENPC_SHAMAN] = "processEvent045_5",
	},
	[SEQ_050] = {
		[ENPC_JAJANZO] = "processEvent050_3",
		[ENPC_COYNACH] = "processEvent050_4",
		[ENPC_SINGLETON] = "processEvent050_5",
		[ENPC_LYNGWAEK] = "processEvent050_6",
		[ENPC_VANNES] = "processEvent050_7",
		[ENPC_TATASHA] = "processEvent050_8",
		[ENPC_UBOKHN] = "processEvent050_9",
		[ENPC_YOYOBINA] = "processEvent050_10",
	},
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_LULUTSU, QFLAG_TALK);
		return;
	end
	if (TALKS[sequence] ~= nil) then
		for classId, _ in pairs(TALKS[sequence]) do
			quest:SetENpc(classId);
		end
	end
	if (sequence == SEQ_000 or sequence == SEQ_003) then
		quest:SetENpc(ENPC_YOYOBINA, QFLAG_TALK);
	elseif (sequence == SEQ_005) then
		quest:SetENpc(ENPC_ARENA_DOORS, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_YOYOBINA);
	elseif (sequence == SEQ_010) then
		-- A lost or abandoned bout: Yoyobina's word, or straight back in.
		quest:SetENpc(ENPC_YOYOBINA, QFLAG_TALK);
		quest:SetENpc(ENPC_ARENA_DOORS, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(ENPC_YOYOBINA, QFLAG_TALK);
	elseif (sequence == SEQ_023 or sequence == SEQ_024) then
		-- SEQ_024 keeps him open: a lost rematch is retried through him.
		quest:SetENpc(ENPC_CHALLENGER, QFLAG_TALK);
	elseif (sequence == SEQ_025) then
		quest:SetENpc(ENPC_YOYOBINA, QFLAG_TALK);
	elseif (sequence == SEQ_030) then
		quest:SetENpc(ENPC_ARENA_DOORS, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_040) then
		quest:SetENpc(ENPC_CHALLENGER, QFLAG_TALK);
	elseif (sequence == SEQ_045) then
		quest:SetENpc(ENPC_BAZAAR_CROWD, QFLAG_PUSH, false, true);
		-- He sends you back if you left the Echo early.
		quest:SetENpc(ENPC_CHALLENGER, QFLAG_TALK);
	elseif (sequence == SEQ_050) then
		quest:SetENpc(ENPC_LULUTSU, QFLAG_REWARD);
	end
end

local function warpToHall(player)
	GetWorldManager():DoZoneChange(player, 209, nil, 0, 15, GUILD_HALL[1], GUILD_HALL[2], GUILD_HALL[3], GUILD_HALL[4]);
end

local function warpToBazaar(player)
	GetWorldManager():DoZoneChange(player, BAZAAR_ZONE, "PrivateAreaMasterPast", BAZAAR_AREA, 15, BAZAAR_ARRIVAL[1], BAZAAR_ARRIVAL[2], BAZAAR_ARRIVAL[3], BAZAAR_ARRIVAL[4]);
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_LULUTSU) then
		-- Your debut is called (1 = accepted).
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventLulutsuStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and npcClassId == ENPC_YOYOBINA) then
		-- The tourney of warriors: hear the other gladiators first.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent003");
		quest:StartSequence(SEQ_003);
	elseif ((seq == SEQ_003 or seq == SEQ_005) and npcClassId == ENPC_YOYOBINA) then
		-- "Are you ready to play the role of gladiator?" (1 = yes: down the
		-- stairs and through the door).
		local ready = callClientFunction(player, "delegateEvent", player, quest, "processEvent005");
		if (ready == 1 and seq == SEQ_003) then
			quest:StartSequence(SEQ_005);
		end
	elseif (seq == SEQ_010 and npcClassId == ENPC_YOYOBINA) then
		-- gla30615: after the loss. It ends on an after-warp fade.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_999");
		quest:StartSequence(SEQ_005);
		player:EndEvent();
		warpToHall(player);
		return;
	elseif (seq == SEQ_020 and npcClassId == ENPC_YOYOBINA) then
		-- Who the Lalafell is.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent023");
		quest:StartSequence(SEQ_023);
	elseif ((seq == SEQ_023 or seq == SEQ_024) and npcClassId == ENPC_CHALLENGER) then
		-- The Echo on him: 1 is the rematch, 0 leaves him waiting.
		local echo = callClientFunction(player, "delegateEvent", player, quest, "processEvent024");
		if (echo == 1) then
			if (seq == SEQ_023) then
				quest:StartSequence(SEQ_024);
			end
			startGla306Bout(player, "Gla30602");
			return;
		end
	elseif (seq == SEQ_025 and npcClassId == ENPC_YOYOBINA) then
		-- gla30630: what you saw in the Echo. It ends on an after-warp fade.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
		quest:StartSequence(SEQ_030);
		player:EndEvent();
		warpToHall(player);
		return;
	elseif ((seq == SEQ_040 or seq == SEQ_045) and npcClassId == ENPC_CHALLENGER) then
		-- The beaten Lalafell, and the Echo on him: 1 takes you to the
		-- Silver Bazaar (the event fades out and waits for the warp).
		local echo = callClientFunction(player, "delegateEvent", player, quest, "processEvent045");
		if (echo == 1) then
			quest:StartSequence(SEQ_045);
			player:EndEvent();
			warpToBazaar(player);
			return;
		end
	elseif (seq == SEQ_050 and npcClassId == ENPC_LULUTSU) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent055");
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
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (npcClassId == ENPC_ARENA_DOORS and seq == SEQ_005) then
		-- gla30610: out onto the sands. It ends on an after-warp fade,
		-- which the move into the bout lifts.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		quest:StartSequence(SEQ_010);
		startGla306Bout(player, "Gla30601");
		return;
	elseif (npcClassId == ENPC_ARENA_DOORS and seq == SEQ_010) then
		-- Straight back in after a loss.
		startGla306Bout(player, "Gla30601");
		return;
	elseif (npcClassId == ENPC_ARENA_DOORS and seq == SEQ_030) then
		-- gla30640: his match, from the stands. It ends on an after-warp
		-- fade.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent040");
		quest:StartSequence(SEQ_040);
		player:EndEvent();
		warpToHall(player);
		return;
	elseif (npcClassId == ENPC_BAZAAR_CROWD and seq == SEQ_045) then
		-- gla30650: Yoyobina and the Ala Mhigans. It ends on an after-warp
		-- fade; the Echo is over.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050");
		quest:StartSequence(SEQ_050);
		player:EndEvent();
		warpToHall(player);
		return;
	end
	player:EndEvent();
end

-- Both bouts are fought on the sands: Gla30601 (the tourney) and Gla30602
-- (the Echo rematch).
function startGla306Bout(player, name)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", name, "SimpleContent" .. name, "Quest/QuestDirector" .. name, 209);
	if (contentArea == nil) then
		player:EndEvent();
		warpToHall(player);
		return;
	end
	local director = contentArea:GetContentDirector();
	player:AddDirector(director);
	director:StartDirector(false);
	player:KickEvent(director, "noticeEvent", true);
	player:SetLoginDirector(director);
	player:EndEvent();
	GetWorldManager():DoZoneChangeContent(player, contentArea, ARENA[1], ARENA[2], ARENA[3], ARENA[4], 16);
end

-- QuestDirectorGla30601/30602, after a win (a loss never signals the
-- director).
function finishGla306Bout(player, quest, actor, rematch)
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	if (rematch) then
		-- The Lalafell's axe; back to the present.
		quest:StartSequence(SEQ_025);
	else
		-- gla30620: the crowd's cheers, and a familiar face. It ends on an
		-- after-warp fade.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		quest:StartSequence(SEQ_020);
	end
	player:EndEvent();
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	warpToHall(player);
end

-- SimpleContentGla30601/30602, on a loss (pinned at 1 HP, or out of time):
-- back to the hall. The sequence (SEQ_010 or SEQ_024) says a bout was lost.
function loseGla306Bout(player, timedOut)
	if (timedOut) then
		player:SendMessage(0x20, "", "Time has run out.");
	else
		player:SendMessage(0x20, "", "You are defeated.");
	end
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	warpToHall(player);
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_000 or seq == SEQ_003 or seq == SEQ_020 or seq == SEQ_025) then
		return MRKR_YOYOBINA;
	elseif (seq == SEQ_005) then
		return MRKR_BOUT;
	elseif (seq == SEQ_010) then
		return MRKR_LOST;
	elseif (seq == SEQ_023 or seq == SEQ_024 or seq == SEQ_040) then
		return MRKR_REPORT;
	elseif (seq == SEQ_030) then
		return MRKR_STANDS;
	elseif (seq == SEQ_045) then
		return MRKR_BAZAAR;
	elseif (seq == SEQ_050) then
		return MRKR_LULUTSU;
	end
end
