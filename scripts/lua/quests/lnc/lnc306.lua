require ("global")
require ("quest")
require ("modifiers")

--[[

Quest Script

Name:	Necessary Evils
Code:	Lnc306
Id:	110182
Prereq: Level 36, Lancer, Lnc300

Willelda asks whether you'd give your life for Gridania and sends you to
J'moldva (lnc30610): the imperials are trying to burn the Hedge, and you
are to guard the Ul'dahn caravan on its way home. On the Central Shroud
road an angry elemental falls on the caravan (lnc30620, content Lnc30601
in the South Shroud, where the next scenes play). Once it is beaten, a
moogle scolds you for helping outsiders (lnc30630); the Echo on the
merchant shows the caravan trying to catch a moogle (processEvent035,
lnc30640 in the South Shroud's past). J'moldva keeps it quiet for the
alliance's sake (lnc30650), and Willelda pays 36,000 gil and 3,600
experience.

The caravan's merchant has no class of its own; a stripped trader body
(1000812) stands in. lnc30630 is played from the merchant once the fight
is over, outside the content area (scenes crash the client inside one).

Journal: rows 96-101 of the quest journal sheet.

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Speak with J'moldva.
SEQ_010	= 10;  -- Find the caravan on the road south.
SEQ_020	= 20;  -- Save the merchants from the elemental.
SEQ_030	= 30;  -- Use the Echo on the merchant.
SEQ_035	= 35;  -- The Echo.
SEQ_040	= 40;  -- Report to J'moldva.
SEQ_050	= 50;  -- Willelda has your reward.

-- Actor Class Ids
ENPC_WILLELDA		= 1000242;
ENPC_JMOLDVA		= 1000599;
ENPC_MERCHANT		= 1000812; -- a stripped trader body, spawned by the caravan
ENPC_ROAD			= 1090521; -- push circle on the Central Shroud road
ENPC_ECHO			= 1090522; -- push circle in the South Shroud's past

-- Quest Markers (the client's index names them lnc30610-30650)
MRKR_JMOLDVA	= 11018201;
MRKR_ROAD		= 11018202;
MRKR_FIGHT		= 11018203;
MRKR_ECHO		= 11018204;
MRKR_REPORT		= 11018205;

-- Quest Flags
FLAG_WON		= 0;  -- the elemental is beaten; lnc30630 plays at the merchant

REWARD_GIL	= 36000;
REWARD_EXP	= 3600;

-- Spots: zone, x, y, z, rotation (cut coordinates on the client's floors).
BARRACKS = { 206, 194.5, 27.9, -1589.1, 3.0 };		-- lnc30610's after-warp, facing J'moldva
ROAD_OUTSIDE = { 150, 355.0, 4.25, -705.0, 3.1 };	-- by the road circle, after a loss
CARAVAN_ZONE = 154;
FIGHT = { 800.7, -11.95, 1380.6, 1.5 };
CARAVAN = { 796.0, -11.95, 1375.4, 0.6 };			-- set down by the merchant
ECHO_AREA = 0;										-- PrivateAreaMasterPast 0 in the South Shroud
ECHO_ARRIVAL = { 929.2, 0.0, 1636.4, 0.8 };

-- Lines whose speakers are certain.
TALKS = {
	[SEQ_000] = {
		[ENPC_WILLELDA] = "processEvent005_2",
	},
	[SEQ_040] = {
		[ENPC_MERCHANT] = "processEvent040_9",
	},
	[SEQ_050] = {
		[ENPC_JMOLDVA] = "processEvent050_2",
	},
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_WILLELDA, QFLAG_TALK);
		return;
	end
	if (TALKS[sequence] ~= nil) then
		for classId, _ in pairs(TALKS[sequence]) do
			quest:SetENpc(classId);
		end
	end
	if (sequence == SEQ_000) then
		quest:SetENpc(ENPC_JMOLDVA, QFLAG_TALK);
	elseif (sequence == SEQ_010 or sequence == SEQ_020) then
		-- Open until the fight is won: a lost fight is retried here.
		quest:SetENpc(ENPC_ROAD, QFLAG_PUSH, false, true);
		if (quest:GetData():GetFlag(FLAG_WON)) then
			quest:SetENpc(ENPC_MERCHANT, QFLAG_TALK);
		end
	elseif (sequence == SEQ_030) then
		quest:SetENpc(ENPC_MERCHANT, QFLAG_TALK);
	elseif (sequence == SEQ_035) then
		quest:SetENpc(ENPC_ECHO, QFLAG_PUSH, false, true);
		-- He sends you back if you left the Echo early.
		quest:SetENpc(ENPC_MERCHANT, QFLAG_TALK);
	elseif (sequence == SEQ_040) then
		quest:SetENpc(ENPC_JMOLDVA, QFLAG_TALK);
	elseif (sequence == SEQ_050) then
		quest:SetENpc(ENPC_WILLELDA, QFLAG_REWARD);
	end
end

local function warpTo(player, spot)
	GetWorldManager():DoZoneChange(player, spot[1], nil, 0, 15, spot[2], spot[3], spot[4], spot[5]);
end

local function warpToCaravan(player)
	GetWorldManager():DoZoneChange(player, CARAVAN_ZONE, nil, 0, 15, CARAVAN[1], CARAVAN[2], CARAVAN[3], CARAVAN[4]);
end

local function warpToEcho(player)
	GetWorldManager():DoZoneChange(player, CARAVAN_ZONE, "PrivateAreaMasterPast", ECHO_AREA, 15, ECHO_ARRIVAL[1], ECHO_ARRIVAL[2], ECHO_ARRIVAL[3], ECHO_ARRIVAL[4]);
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();
	local data = quest:GetData();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_WILLELDA) then
		-- Would you give your life for Gridania? (1 = accepted)
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventWilleldaStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and npcClassId == ENPC_JMOLDVA) then
		-- lnc30610: news from Ul'dah, and the Hedge afire. It ends on an
		-- after-warp fade.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		quest:StartSequence(SEQ_010);
		quest:UpdateENPCs();
		player:EndEvent();
		warpTo(player, BARRACKS);
		return;
	elseif (seq == SEQ_020 and npcClassId == ENPC_MERCHANT and data:GetFlag(FLAG_WON)) then
		-- lnc30630: the moogle's scolding. It ends on an after-warp fade.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
		quest:StartSequence(SEQ_030);
		quest:UpdateENPCs();
		player:EndEvent();
		warpToCaravan(player);
		return;
	elseif ((seq == SEQ_030 or seq == SEQ_035) and npcClassId == ENPC_MERCHANT) then
		-- The merchant, and the Echo (1 = look).
		local echo = callClientFunction(player, "delegateEvent", player, quest, "processEvent035");
		if (echo == 1) then
			if (seq == SEQ_030) then
				quest:StartSequence(SEQ_035);
			end
			quest:UpdateENPCs();
			player:EndEvent();
			warpToEcho(player);
			return;
		end
	elseif (seq == SEQ_040 and npcClassId == ENPC_JMOLDVA) then
		-- lnc30650: J'moldva keeps it quiet.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050");
		quest:StartSequence(SEQ_050);
	elseif (seq == SEQ_050 and npcClassId == ENPC_WILLELDA) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent060");
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

	if (npcClassId == ENPC_ROAD and (seq == SEQ_010 or seq == SEQ_020) and not quest:GetData():GetFlag(FLAG_WON)) then
		-- lnc30620: the caravan, and the elemental. It ends on an after-warp
		-- fade, which the move into the fight lifts.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		if (seq == SEQ_010) then
			quest:StartSequence(SEQ_020);
		end
		startLnc306Fight(player, quest);
		return;
	elseif (npcClassId == ENPC_ECHO and seq == SEQ_035) then
		-- lnc30640: the merchants chasing a moogle. Back to the present.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent040");
		quest:StartSequence(SEQ_040);
		quest:UpdateENPCs();
		player:EndEvent();
		warpToCaravan(player);
		return;
	end
	player:EndEvent();
end

function startLnc306Fight(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Lnc30601", "SimpleContentLnc30601", "Quest/QuestDirectorLnc30601", CARAVAN_ZONE);
	if (contentArea == nil) then
		player:EndEvent();
		warpTo(player, ROAD_OUTSIDE);
		return;
	end
	local director = contentArea:GetContentDirector();
	player:AddDirector(director);
	director:StartDirector(false);
	player:KickEvent(director, "noticeEvent", true);
	player:SetLoginDirector(director);
	player:EndEvent();
	GetWorldManager():DoZoneChangeContent(player, contentArea, FIGHT[1], FIGHT[2], FIGHT[3], FIGHT[4], 16);
end

-- QuestDirectorLnc30601, once the elemental is down (a loss never signals
-- the director). The scene after it plays at the merchant.
function finishLnc306Fight(player, quest, actor)
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	quest:GetData():SetFlag(FLAG_WON);
	player:EndEvent();
	player:SendMessage(0x20, "", "The elemental is defeated.");
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	warpToCaravan(player);
end

-- SimpleContentLnc30601, on a loss (pinned at 1 HP, or out of time): set
-- down by the road to try again.
function loseLnc306Fight(player, timedOut)
	if (timedOut) then
		player:SendMessage(0x20, "", "Time has run out.");
	else
		player:SendMessage(0x20, "", "You are defeated.");
	end
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	warpTo(player, ROAD_OUTSIDE);
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_000) then
		return MRKR_JMOLDVA;
	elseif (seq == SEQ_010) then
		return MRKR_ROAD;
	elseif (seq == SEQ_020) then
		return MRKR_FIGHT;
	elseif (seq == SEQ_030 or seq == SEQ_035) then
		return MRKR_ECHO;
	elseif (seq == SEQ_040) then
		return MRKR_REPORT;
	end
end
