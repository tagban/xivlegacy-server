require ("global")
require ("quest")
require ("modifiers")

--[[

Quest Script

Name:	Revelry in Rivalry
Code:	Thm300
Id:	110241
Prereq: Level 30, Thaumaturge

Keeper Yayake sends you west across the sea to sell graves at Arrzaneth
Ossuary to the Lominsans (thm30010), and the novice who trains alongside you
lets you know she is off to Ishgard and means to beat you (thm30020). In
Limsa, Baderon has no buyers for you, but word of a Naldiq & Vymelli's
runner chased by a beast north of Camp Bearded Rock. Drive it off (content
Thm30001) and take what the runner was carrying to Bodenolf, who knows it
for a dead woman's trinket buried at the Ossuary; the Echo shows him and
the shipwright Joellaut buying it from your rival (thm30030). Report to
Yayake, hear your rival out (thm30040), and Yayake pays you 30,000 gil and
3,000 experience.

]]

-- Sequence Numbers
SEQ_010	= 10;  -- Speak with the novice in the guild hall.
SEQ_020	= 20;  -- Seek out Baderon in Limsa Lominsa.
SEQ_025	= 25;  -- Find the runner north of Camp Bearded Rock.
SEQ_027	= 27;  -- Take the runner's trinket to Bodenolf.
SEQ_030	= 30;  -- Speak with Bodenolf again.
SEQ_035	= 35;  -- Report to Yayake.
SEQ_040	= 40;  -- Speak with your fellow novice.
SEQ_050	= 50;  -- Speak with Yayake.

-- Actor Class Ids
ENPC_YAYAKE			= 1000846;
ENPC_NOVICE			= 1000607; -- seed 290: the overweening thaumaturge
ENPC_GOGOFU			= 1000046;
ENPC_WAWATON		= 1000648;
ENPC_TOTONO			= 1001143;
ENPC_KAMLITO_HALITO	= 1001142;
ENPC_FYRILSUNN		= 1001144;
ENPC_BADERON		= 1000137;
ENPC_BODENOLF		= 1000144;
ENPC_RUNNER_SPOT	= 1090508; -- seed 290: push circle north of Camp Bearded Rock

-- Quest Markers
MRKR_NOVICE		= 11024101;
MRKR_BADERON	= 11024102;
MRKR_RUNNER		= 11024103;
MRKR_BODENOLF	= 11024104;
MRKR_YAYAKE		= 11024105;

REWARD_GIL	= 30000;
REWARD_EXP	= 3000;

-- In front of the novice's corner; the guild hall scenes end on an
-- after-warp fade, which a warp back to this spot lifts.
GUILD_HALL = { -297.0, 206.0, 224.3, -0.74 };
-- The grass flat south of Camp Bearded Rock: where the beast is fought
-- (facing east, toward it), and where you are set down afterwards. Heights
-- are walked ground; a guessed height drops you under the terrain.
MEADOW_FIGHT = { 58.75, 42.50, 227.19, 1.57 };
MEADOW_GROUND = { 58.75, 42.50, 227.19, -1.57 };

-- The guild's word for a novice bound for Limsa (010_2..7), for one back
-- empty-handed (030_3..7), and on the rival's success (040_2..4). The
-- speakers follow the order Thm200 uses for the same hall; the client
-- script doesn't name them.
TALKS_010 = {
	[ENPC_YAYAKE] = "processEvent010_2",
	[ENPC_GOGOFU] = "processEvent010_3",
	[ENPC_WAWATON] = "processEvent010_4",
	[ENPC_TOTONO] = "processEvent010_5",
	[ENPC_KAMLITO_HALITO] = "processEvent010_6",
	[ENPC_FYRILSUNN] = "processEvent010_7",
};
TALKS_035 = {
	[ENPC_GOGOFU] = "processEvent030_3",
	[ENPC_WAWATON] = "processEvent030_4",
	[ENPC_TOTONO] = "processEvent030_5",
	[ENPC_KAMLITO_HALITO] = "processEvent030_6",
	[ENPC_FYRILSUNN] = "processEvent030_7",
};
TALKS_040 = {
	[ENPC_YAYAKE] = "processEvent035_2",
	[ENPC_GOGOFU] = "processEvent040_2",
	[ENPC_WAWATON] = "processEvent040_3",
	[ENPC_TOTONO] = "processEvent040_4",
};
-- Bodenolf before you bring him anything (025_1, 025_2), and after the
-- Echo (030_8).
TALKS_BODENOLF = {
	[SEQ_020] = "processEvent025_1",
	[SEQ_025] = "processEvent025_2",
	[SEQ_035] = "processEvent030_8",
	[SEQ_040] = "processEvent030_8",
	[SEQ_050] = "processEvent030_8",
};

function onStart(player, quest)
	quest:StartSequence(SEQ_010);
end

function onFinish(player, quest)
end

local function setTalks(quest, talks)
	for classId, _ in pairs(talks) do
		quest:SetENpc(classId);
	end
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_YAYAKE, QFLAG_TALK);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_NOVICE, QFLAG_TALK);
		setTalks(quest, TALKS_010);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(ENPC_BADERON, QFLAG_TALK);
		quest:SetENpc(ENPC_BODENOLF);
	elseif (sequence == SEQ_025) then
		-- Stays open: a lost or abandoned fight is retried from here.
		quest:SetENpc(ENPC_RUNNER_SPOT, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_BODENOLF);
	elseif (sequence == SEQ_027 or sequence == SEQ_030) then
		quest:SetENpc(ENPC_BODENOLF, QFLAG_TALK);
	elseif (sequence == SEQ_035) then
		quest:SetENpc(ENPC_YAYAKE, QFLAG_TALK);
		quest:SetENpc(ENPC_BODENOLF);
		setTalks(quest, TALKS_035);
	elseif (sequence == SEQ_040) then
		quest:SetENpc(ENPC_NOVICE, QFLAG_TALK);
		quest:SetENpc(ENPC_BODENOLF);
		setTalks(quest, TALKS_040);
	elseif (sequence == SEQ_050) then
		quest:SetENpc(ENPC_YAYAKE, QFLAG_REWARD);
		quest:SetENpc(ENPC_BODENOLF);
	end
end

local function backToHall(player)
	GetWorldManager():DoZoneChange(player, 209, nil, 0, 15, GUILD_HALL[1], GUILD_HALL[2], GUILD_HALL[3], GUILD_HALL[4]);
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_YAYAKE) then
		-- The offer: thm30010 asks whether you will peddle graves in Limsa.
		-- Accepting ends it on an after-warp fade.
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventYayakeStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		if (accepted == 1) then
			backToHall(player);
		end
		return;
	elseif (npcClassId == ENPC_NOVICE and seq == SEQ_010) then
		-- thm30020: your rival is bound for Ishgard.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		quest:StartSequence(SEQ_020);
		player:EndEvent();
		backToHall(player);
		return;
	elseif (npcClassId == ENPC_NOVICE and seq == SEQ_040) then
		-- thm30040: the rival answers your charge.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent040");
		quest:StartSequence(SEQ_050);
		player:EndEvent();
		backToHall(player);
		return;
	elseif (npcClassId == ENPC_BADERON and seq == SEQ_020) then
		-- No buyers in Limsa, but a runner in trouble north of the camp.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent025");
		quest:StartSequence(SEQ_025);
	elseif (npcClassId == ENPC_BODENOLF and seq == SEQ_027) then
		-- The runner lived: Bodenolf knows the trinket (028; 027 is the
		-- telling where she died).
		callClientFunction(player, "delegateEvent", player, quest, "processEvent028");
		quest:StartSequence(SEQ_030);
	elseif (npcClassId == ENPC_BODENOLF and seq == SEQ_030) then
		-- The Echo: 1 sees the trinket sold to Joellaut (thm30030).
		local echo = callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
		if (echo == 1) then
			quest:StartSequence(SEQ_035);
		end
	elseif (npcClassId == ENPC_BODENOLF and TALKS_BODENOLF[seq] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, TALKS_BODENOLF[seq]);
	elseif (npcClassId == ENPC_YAYAKE and seq == SEQ_035) then
		-- No contracts, and a tale of graverobbing. It ends on an after-warp
		-- fade.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent035");
		quest:StartSequence(SEQ_040);
		player:EndEvent();
		backToHall(player);
		return;
	elseif (npcClassId == ENPC_YAYAKE and seq == SEQ_050) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 2);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddGil(REWARD_GIL);
		player:CompleteQuest(quest);
	elseif (seq == SEQ_010 and TALKS_010[npcClassId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, TALKS_010[npcClassId]);
	elseif (seq == SEQ_035 and TALKS_035[npcClassId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, TALKS_035[npcClassId]);
	elseif (seq == SEQ_040 and TALKS_040[npcClassId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, TALKS_040[npcClassId]);
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_025 and npcClassId == ENPC_RUNNER_SPOT) then
		startThm300Fight(player, quest);
		return;
	end
	quest:UpdateENPCs();
	player:EndEvent();
end

function startThm300Fight(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Thm30001", "SimpleContentThm30001", "Quest/QuestDirectorThm30001", 128);
	if (contentArea == nil) then
		player:EndEvent();
		return;
	end
	local director = contentArea:GetContentDirector();
	player:AddDirector(director);
	director:StartDirector(false);
	player:KickEvent(director, "noticeEvent", true);
	player:SetLoginDirector(director);
	player:EndEvent();
	GetWorldManager():DoZoneChangeContent(player, contentArea, MEADOW_FIGHT[1], MEADOW_FIGHT[2], MEADOW_FIGHT[3], MEADOW_FIGHT[4], 16);
end

-- QuestDirectorThm30001, once the beast is down (a loss never signals the
-- director). The runner's thanks belong to a client script 1.23b doesn't
-- ship, so the server says it.
function finishThm300Fight(player, quest, actor)
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	player:SendMessage(0x20, "", "The runner thanks you and presses a trinket into your hands for Bodenolf of Naldiq & Vymelli's.");
	quest:StartSequence(SEQ_027);
	player:EndEvent();
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	GetWorldManager():DoZoneChange(player, 128, nil, 0, 15, MEADOW_GROUND[1], MEADOW_GROUND[2], MEADOW_GROUND[3], MEADOW_GROUND[4]);
end

-- SimpleContentThm30001, on a loss: set down in the meadow to try again.
-- The director runs in its own Lua state and can't see it.
function loseThm300Fight(player)
	player:SendMessage(0x20, "", "You are defeated.");
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	GetWorldManager():DoZoneChange(player, 128, nil, 0, 15, MEADOW_GROUND[1], MEADOW_GROUND[2], MEADOW_GROUND[3], MEADOW_GROUND[4]);
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_010 or seq == SEQ_040) then
		return MRKR_NOVICE;
	elseif (seq == SEQ_020) then
		return MRKR_BADERON;
	elseif (seq == SEQ_025) then
		return MRKR_RUNNER;
	elseif (seq == SEQ_027 or seq == SEQ_030) then
		return MRKR_BODENOLF;
	elseif (seq == SEQ_035 or seq == SEQ_050) then
		return MRKR_YAYAKE;
	end
end
