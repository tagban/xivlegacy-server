require ("global")
require ("quest")
require ("modifiers")

--[[

Quest Script

Name:	Captain's Orders
Code:	Exc306
Id:	110102
Prereq: Level 36, Marauder, Exc300

Waekbyrt sends you through the door behind him to the chief, Hyllfyr,
who wanted Rostnsthal and got you (exc30610). Moenskaet the Honorbound
beats you senseless (content Exc30601, a fight you can't win: it ends at
1 HP or after five minutes) and the grunts dump you in a Consortium
alehold (exc30620). There a "???" turns out to be Rostnsthal in a rum
barrel (exc30630, content Exc30601 again). Back on the Astalicia Waekbyrt
sends you to the lounge (processEvent035), where the captains bicker
(exc30640), and on deck Rostnsthal hands you the Kraken Register to take
to the captain (exc30650). Behind the doors Moenskaet and his two hands
are waiting (content Exc30602); after the win (exc30660) Rostnsthal's Echo
shows what he tried to do with the register (processEvent070), and
Waekbyrt pays 36,000 gil and 3,600 experience.

The Sailors Ward has no maps for the captain's quarters or the alehold,
so the fights are staged in the lounge and the alehold in the hold of the
Rhotano Sea ship (zone 192), as Exc300's den is. The doors are push
circles (seed: triggers 1090523, 1090525-1090527). exc30620 plays at a
circle by Waekbyrt after the first fight, and exc30660 at the deck doors
after the second, outside the content areas (scenes crash the client
inside one).

Journal: rows 66-75 of the quest journal sheet.

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Go through the door behind Waekbyrt.
SEQ_010	= 10;  -- Moenskaet's beating.
SEQ_020	= 20;  -- Wake in the alehold; look for a clue.
SEQ_030	= 30;  -- Return to the Astalicia.
SEQ_035	= 35;  -- Find Rostnsthal in the lounge.
SEQ_040	= 40;  -- Meet him above decks.
SEQ_050	= 50;  -- Deliver the register to the captain.
SEQ_060	= 60;  -- Tell Rostnsthal.
SEQ_070	= 70;  -- Report to Waekbyrt.

-- Actor Class Ids
ENPC_WAEKBYRT		= 1000003;
ENPC_ROSTNSTHAL		= 1000005;
ENPC_CHICHIROON		= 1000217;
ENPC_MIMIROON		= 1000221;
ENPC_QUARTERS_DOOR	= 1090523; -- push circle at the door by Waekbyrt
ENPC_ALEHOLD		= 1090525; -- push circle by Waekbyrt, after the beating
ENPC_DECK			= 1090526; -- push circle on deck
ENPC_DECK_DOORS		= 1090527; -- push circle at the deck's double doors
ENPC_BARREL			= 1080024; -- the "???", spawned by SimpleContentExc30603

-- Items
ITEM_KRAKEN_REGISTER	= 11000132;

-- Quest Markers (the client's index names them exc30610-30670)
MRKR_DOOR		= 11010201;
MRKR_BARREL		= 11010203;
MRKR_LOUNGE		= 11010204;
MRKR_DECK		= 11010205;
MRKR_DOORS		= 11010206;
MRKR_ECHO		= 11010207;

-- Quest Flags
FLAG_WON		= 0;  -- Moenskaet and his hands are beaten; exc30660 plays at the doors

-- Lines from the quest's sheet (SendGameMessage ids).
LINE_NO_HONOR		= 156;
LINE_DEFEATED		= 157;
LINE_NO_FUN			= 158;
LINE_INDISPOSED		= 53;
LINE_WORM			= 164;

REWARD_GIL	= 36000;
REWARD_EXP	= 3600;

-- Spots: zone, x, y, z, rotation.
WAEKBYRT_SPOT = { 230, -753.8, 7.35, 385.5, 1.5 };	-- facing Waekbyrt (walked for Exc300)
LOUNGE_SPOT = { 230, -789.9, 9.15, 387.4, 1.57 };	-- by Rostnsthal (walked for Exc300)
DOCKS = { 230, -422.8, 42.0, 418.5, 0.0 };			-- Exc300's Sailors Terrace spot
ALEHOLD_ENTRY = { 192, 1823.58, -61.65, 1816.1, 2.42 };	-- the ship hold drop (as Exc300)
DUMPED = WAEKBYRT_SPOT;							-- on the alehold circle
DECK_SPOT = { 230, -791.1, 21.35, 383.0, 0.0 };		-- on deck, between the circles
FIGHT = { -789.9, 9.15, 387.4, 1.57 };				-- the lounge (content copy)

-- Lines whose speakers are certain.
TALKS = {
	[SEQ_000] = {
		[ENPC_WAEKBYRT] = "processEvent001_2",
		[ENPC_CHICHIROON] = "processEvent001_17",
		[ENPC_MIMIROON] = "processEvent001_18",
	},
	[SEQ_030] = {
		[ENPC_ROSTNSTHAL] = "processEvent033",
	},
	[SEQ_050] = {
		[ENPC_WAEKBYRT] = "processEvent050_2",
	},
	[SEQ_070] = {
		[ENPC_ROSTNSTHAL] = "processEvent070_2",
	},
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_WAEKBYRT, QFLAG_TALK);
		return;
	end
	if (TALKS[sequence] ~= nil) then
		for classId, _ in pairs(TALKS[sequence]) do
			quest:SetENpc(classId);
		end
	end
	if (sequence == SEQ_000 or sequence == SEQ_010) then
		-- Open through the beating: a fight left early is begun again here.
		quest:SetENpc(ENPC_QUARTERS_DOOR, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_020) then
		-- Open until the barrel is found: the alehold is entered again here.
		quest:SetENpc(ENPC_ALEHOLD, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_BARREL, QFLAG_TALK);
	elseif (sequence == SEQ_030) then
		quest:SetENpc(ENPC_WAEKBYRT, QFLAG_TALK);
	elseif (sequence == SEQ_035) then
		quest:SetENpc(ENPC_ROSTNSTHAL, QFLAG_TALK);
	elseif (sequence == SEQ_040) then
		quest:SetENpc(ENPC_DECK, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_050) then
		-- Open until the fight is won, and once more for exc30660.
		quest:SetENpc(ENPC_DECK_DOORS, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_060) then
		quest:SetENpc(ENPC_ROSTNSTHAL, QFLAG_TALK);
	elseif (sequence == SEQ_070) then
		quest:SetENpc(ENPC_WAEKBYRT, QFLAG_REWARD);
	end
end

local function warpTo(player, spot)
	GetWorldManager():DoZoneChange(player, spot[1], nil, 0, 15, spot[2], spot[3], spot[4], spot[5]);
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_WAEKBYRT) then
		-- The chief has business with Rostnsthal (1 = accepted).
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventWaekbyrtStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_020 and npcClassId == ENPC_BARREL) then
		-- exc30630: Rostnsthal in a rum barrel. It ends on an after-warp
		-- fade: out to the docks.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
		quest:StartSequence(SEQ_030);
		quest:UpdateENPCs();
		player:EndEvent();
		player:GetZone():ContentFinished();
		warpTo(player, DOCKS);
		return;
	elseif (seq == SEQ_030 and npcClassId == ENPC_WAEKBYRT) then
		-- Where have you been? The captain isn't finished with you.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent035");
		quest:StartSequence(SEQ_035);
	elseif (seq == SEQ_035 and npcClassId == ENPC_ROSTNSTHAL) then
		-- exc30640: the captains in the lounge. It ends on an after-warp fade.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent040");
		quest:StartSequence(SEQ_040);
		quest:UpdateENPCs();
		player:EndEvent();
		warpTo(player, LOUNGE_SPOT);
		return;
	elseif (seq == SEQ_060 and npcClassId == ENPC_ROSTNSTHAL) then
		-- The Echo (1 = look); exc30670 is the whole of it.
		local echo = callClientFunction(player, "delegateEvent", player, quest, "processEvent070");
		if (echo == 1) then
			quest:StartSequence(SEQ_070);
		end
	elseif (seq == SEQ_070 and npcClassId == ENPC_WAEKBYRT) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent080");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 2);
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(ITEM_KRAKEN_REGISTER, 1);
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
	local data = quest:GetData();

	if (npcClassId == ENPC_QUARTERS_DOOR and (seq == SEQ_000 or seq == SEQ_010)) then
		-- exc30610: the chief wanted Rostnsthal. It ends on an after-warp
		-- fade, which the move into the fight lifts.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		if (seq == SEQ_000) then
			quest:StartSequence(SEQ_010);
		end
		startExc306Content(player, "SimpleContentExc30601", "Quest/QuestDirectorExc30601", FIGHT[1], FIGHT[2], FIGHT[3], FIGHT[4], 230);
		return;
	elseif (npcClassId == ENPC_ALEHOLD and seq == SEQ_020) then
		-- exc30620: dumped in the alehold. It ends on an after-warp fade.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		startExc306Content(player, "SimpleContentExc30603", "Quest/QuestDirectorExc30601", ALEHOLD_ENTRY[2], ALEHOLD_ENTRY[3], ALEHOLD_ENTRY[4], ALEHOLD_ENTRY[5], ALEHOLD_ENTRY[1]);
		return;
	elseif (npcClassId == ENPC_DECK and seq == SEQ_040) then
		-- exc30650: the register, handed over where you stand (0 = no warp).
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050", 0);
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(ITEM_KRAKEN_REGISTER, 1, 1);
		player:SendGameMessage(GetWorldMaster(), 25246, MESSAGE_TYPE_SYSTEM, ITEM_KRAKEN_REGISTER, 1);
		quest:StartSequence(SEQ_050);
	elseif (npcClassId == ENPC_DECK_DOORS and seq == SEQ_050) then
		if (data:GetFlag(FLAG_WON)) then
			-- exc30660: the aftermath. It ends on an after-warp fade.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent060");
			quest:StartSequence(SEQ_060);
			quest:UpdateENPCs();
			player:EndEvent();
			warpTo(player, DECK_SPOT);
			return;
		end
		-- Moenskaet and his hands, behind the doors.
		player:SendGameMessage(quest, LINE_INDISPOSED, 0x20);
		startExc306Content(player, "SimpleContentExc30602", "Quest/QuestDirectorExc30602", FIGHT[1], FIGHT[2], FIGHT[3], FIGHT[4], 230);
		return;
	end
	quest:UpdateENPCs();
	player:EndEvent();
end

function startExc306Content(player, contentScript, directorName, x, y, z, rot, zoneId)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Exc30601", contentScript, directorName, zoneId);
	if (contentArea == nil) then
		player:EndEvent();
		warpTo(player, WAEKBYRT_SPOT);
		return;
	end
	local director = contentArea:GetContentDirector();
	player:AddDirector(director);
	director:StartDirector(false);
	player:KickEvent(director, "noticeEvent", true);
	player:SetLoginDirector(director);
	player:EndEvent();
	GetWorldManager():DoZoneChangeContent(player, contentArea, x, y, z, rot, 16);
end

-- SimpleContentExc30601, when the beating is over (pinned at 1 HP, or after
-- five minutes): that is the way on, not a loss.
function endExc306Beating(player)
	local quest = player:GetQuest(110102);
	player:SendGameMessage(quest, LINE_NO_HONOR, 0x20);
	player:SendGameMessage(quest, LINE_DEFEATED, 0x20);
	player:SendGameMessage(quest, LINE_NO_FUN, 0x20);
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	quest:StartSequence(SEQ_020);
	quest:UpdateENPCs();
	player:GetZone():ContentFinished();
	warpTo(player, DUMPED);
end

-- QuestDirectorExc30602, once Moenskaet and his hands are down (a loss
-- never signals the director). exc30660 plays at the doors.
function finishExc306Fight(player, quest, actor)
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	quest:GetData():SetFlag(FLAG_WON);
	player:EndEvent();
	player:SendGameMessage(quest, LINE_WORM, 0x20);
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	warpTo(player, DECK_SPOT);
end

-- SimpleContentExc30602, on a loss (pinned at 1 HP, or out of time): back on
-- deck to try the doors again.
function loseExc306Fight(player, timedOut)
	if (timedOut) then
		player:SendMessage(0x20, "", "Time has run out.");
	else
		player:SendMessage(0x20, "", "You are defeated.");
	end
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	warpTo(player, DECK_SPOT);
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_000 or seq == SEQ_030 or seq == SEQ_070) then
		return MRKR_DOOR;
	elseif (seq == SEQ_020) then
		return MRKR_BARREL;
	elseif (seq == SEQ_035) then
		return MRKR_LOUNGE;
	elseif (seq == SEQ_040) then
		return MRKR_DECK;
	elseif (seq == SEQ_050) then
		return MRKR_DOORS;
	elseif (seq == SEQ_060) then
		return MRKR_ECHO;
	end
end
