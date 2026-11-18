require ("global")
require ("quest")
require ("modifiers")

--[[

Quest Script

Name:	Two-man Crew
Code:	Exc300
Id:	110101
Prereq: Level 30, Marauder

Waekbyrt asks whether you'll join the Trident (exc30010, the choice is in
the cut) and sends you up to the lounge, where Rostnsthal, ol' Rusty Steel,
talks you into breaking into the Krakens' den (exc30020). In the den
(content Exc30001) you read three papers: the watchman's log, a bill of
sale and a tattered parchment (trialObject 1-3). Rostnsthal takes them
(processEvent022) and sends you to Rorojaru in Ul'dah (processEvent025).
Back on the Astalicia the 'Cudas have taken Rostnsthal; Waekbyrt tells you
so and pays 30,000 gil and 3,000 experience (exc30030).

The Sailors Ward has no map of its own, so the den is staged in the hold
of the Rhotano Sea ship in zone 192, as Pgl300's Misery is, and the way in
is a push circle by the Market Wards door (seed: trigger 1090519).
Rostnsthal's Limsa body (1000005) ships without events; the data gives
him his ship body's events and a seat in the lounge.

Journal: rows 34-38 of the quest journal sheet.

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Find Rostnsthal in the lounge.
SEQ_010	= 10;  -- Break into the Krakens' den.
SEQ_020	= 20;  -- Bring the papers to Rostnsthal.
SEQ_025	= 25;  -- Speak with Rorojaru on Sapphire Avenue.
SEQ_030	= 30;  -- Return to the Astalicia.

-- Actor Class Ids
ENPC_WAEKBYRT		= 1000003;
ENPC_ROSTNSTHAL		= 1000005;
ENPC_CHICHIROON		= 1000217;
ENPC_MIMIROON		= 1000221;
ENPC_ROROJARU		= 1000374;
ENPC_DEN_DOOR		= 1090519; -- push circle by the Market Wards door
ENPC_DEN_LOG		= 1080021; -- sparkles spawned by SimpleContentExc30001
ENPC_DEN_BILL		= 1080022;
ENPC_DEN_PARCHMENT	= 1080023;

-- Quest Markers (only three exist: exc30010/20/30)
MRKR_WAEKBYRT	= 11010101;
MRKR_ROSTNSTHAL	= 11010102;
MRKR_RETURN		= 11010103;

-- Quest Flags
FLAG_READ_LOG		= 0;
FLAG_READ_BILL		= 1;
FLAG_READ_PARCHMENT	= 2;

-- The den's papers: class, flag, trialObject number.
PAPERS = {
	{ class = ENPC_DEN_LOG, flag = FLAG_READ_LOG, n = 1 },
	{ class = ENPC_DEN_BILL, flag = FLAG_READ_BILL, n = 2 },
	{ class = ENPC_DEN_PARCHMENT, flag = FLAG_READ_PARCHMENT, n = 3 },
};

-- Reward from ZAM (the client's reward row is the generic one).
REWARD_GIL	= 30000;
REWARD_EXP	= 3000;

-- Spots: zone, x, y, z, rotation.
WAEKBYRT_SPOT = { 230, -753.8, 7.35, 385.5, 1.5 };	-- exc30010's after-warp, facing Waekbyrt
LOUNGE_SPOT = { 230, -789.9, 9.15, 387.4, 1.57 };	-- exc30020's after-warp, by Rostnsthal
DEN_ENTRY = { 192, 1823.58, -61.65, 1816.1, 2.42 };	-- the ship hold drop (as Pgl300)
SAILORS_TERRACE = { 230, -422.8, 42.0, 418.5, 0.0 };	-- by the Market Wards door

-- Chatter whose speakers the lines name or place for certain.
TALKS = {
	[SEQ_000] = {
		[ENPC_WAEKBYRT] = "processEvent010_2",
		[ENPC_CHICHIROON] = "processEvent010_13",
		[ENPC_MIMIROON] = "processEvent010_14",
	},
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	local data = quest:GetData();
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_WAEKBYRT, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ENPC_ROSTNSTHAL, QFLAG_TALK);
		quest:SetENpc(ENPC_WAEKBYRT);
		quest:SetENpc(ENPC_CHICHIROON);
		quest:SetENpc(ENPC_MIMIROON);
	elseif (sequence == SEQ_010) then
		-- The door stays open: an abandoned den is tried again there.
		quest:SetENpc(ENPC_DEN_DOOR, QFLAG_PUSH, false, true);
		for _, paper in ipairs(PAPERS) do
			quest:SetENpc(paper.class, data:GetFlag(paper.flag) and QFLAG_NONE or QFLAG_TALK);
		end
	elseif (sequence == SEQ_020) then
		quest:SetENpc(ENPC_ROSTNSTHAL, QFLAG_TALK);
	elseif (sequence == SEQ_025) then
		quest:SetENpc(ENPC_ROROJARU, QFLAG_TALK);
	elseif (sequence == SEQ_030) then
		quest:SetENpc(ENPC_WAEKBYRT, QFLAG_REWARD);
	end
end

local function warpTo(player, spot)
	GetWorldManager():DoZoneChange(player, spot[1], nil, 0, 15, spot[2], spot[3], spot[4], spot[5]);
end

local function paperFor(classId)
	for _, paper in ipairs(PAPERS) do
		if (paper.class == classId) then
			return paper;
		end
	end
	return nil;
end

local function allPapersRead(data)
	for _, paper in ipairs(PAPERS) do
		if (not data:GetFlag(paper.flag)) then
			return false;
		end
	end
	return true;
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();
	local data = quest:GetData();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_WAEKBYRT) then
		-- exc30010: the Trident's choice is inside the cut (1 = join). A
		-- yes ends on an after-warp fade.
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventWaekbyrtStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
			player:EndEvent();
			warpTo(player, WAEKBYRT_SPOT);
			return;
		end
	elseif (seq == SEQ_000 and npcClassId == ENPC_ROSTNSTHAL) then
		-- exc30020: ol' Rusty Steel's plan (1 = in). A yes ends on an
		-- after-warp fade.
		local answer = callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		if (answer == 1) then
			quest:StartSequence(SEQ_010);
			quest:UpdateENPCs();
			player:EndEvent();
			warpTo(player, LOUNGE_SPOT);
			return;
		end
	elseif (seq == SEQ_010 and paperFor(npcClassId) ~= nil) then
		readPaper(player, quest, npc, paperFor(npcClassId));
		return;
	elseif (seq == SEQ_020 and npcClassId == ENPC_ROSTNSTHAL) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent022");
		quest:StartSequence(SEQ_025);
	elseif (seq == SEQ_025 and npcClassId == ENPC_ROROJARU) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent025");
		quest:StartSequence(SEQ_030);
	elseif (seq == SEQ_030 and npcClassId == ENPC_WAEKBYRT) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
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

-- A paper in the den: its text, then it is gone. The third one done, you
-- slip out by the Market Wards door.
function readPaper(player, quest, npc, paper)
	local data = quest:GetData();
	callClientFunction(player, "delegateEvent", player, quest, "trialObject", paper.n);
	data:SetFlag(paper.flag);
	player:HideActor(npc.Id);
	if (allPapersRead(data)) then
		quest:StartSequence(SEQ_020);
		quest:UpdateENPCs();
		player:EndEvent();
		player:GetZone():ContentFinished();
		warpTo(player, SAILORS_TERRACE);
		return;
	end
	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_010 and npcClassId == ENPC_DEN_DOOR) then
		startExc300Den(player, quest);
		return;
	end
	player:EndEvent();
end

function startExc300Den(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Exc30001", "SimpleContentExc30001", "Quest/QuestDirectorExc30001", DEN_ENTRY[1]);
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
	GetWorldManager():DoZoneChangeContent(player, contentArea, DEN_ENTRY[2], DEN_ENTRY[3], DEN_ENTRY[4], DEN_ENTRY[5], 16);
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_000 or seq == SEQ_020) then
		return MRKR_ROSTNSTHAL;
	elseif (seq == SEQ_030) then
		return MRKR_RETURN;
	end
end
