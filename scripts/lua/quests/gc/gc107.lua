require ("global")
require ("quest")
require ("dungeon")

--[[

Quest Script (shared by the three nations)

Name: 	To Kill a Raven
Code: 	Gcl107 / Gcg107 / Gcu107
Id: 	111433 / 111633 / 111833
Prereq: United We Stand (Gc?106), a sworn member of the company
		(company_gate in quest_offers.rs).

The alliance has found Nael van Darnus. Your officer sends you to an
emergency council at the Lotus Stand (Kinnison takes you there), where your
nation's leader orders you to scout south and east of Camp Glory in
Coerthas. There a floating isle rises skyward and Dalamud answers with
fiery boulders (cut scene gc010710). Back at the Lotus Stand your leader
orders an assault on the isle, and Cid offers his airship, the Enterprise.
Gregory, waiting in the clearing before the Lotus Stand, puts you aboard;
Cid asks once more whether you will fly (gc010714). On Rivenroad you face
van Darnus himself, who calls Dalamud's power down upon himself as he falls.
Cid meets you back in the clearing, and Kinnison takes you to the Lotus
Stand for the alliance's thanks (gc010750), which closes the quest.

The client runs one script for all three quests (Gcl107; Gcg107 and Gcu107
are empty stubs); its talks take the nation as their argument. Each nation's
quest script sets NATION and loads this one. Seed 152 holds Merlwyb and
Raubahn at the Lotus Stand, Gregory and Cid in the clearing, the Coerthas
trigger and van Darnus; the battle runs as content (dungeon.lua
"rivenroad", director InstanceRaidLesserWhiteGeneral).

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Attend the council at the Lotus Stand.
SEQ_010	= 10;	-- Hear your nation's leader.
SEQ_020	= 20;	-- Scout the area south and east of Camp Glory.
SEQ_030	= 30;	-- Report to your nation's leader at the Lotus Stand.
SEQ_040	= 40;	-- Consult Cid.
SEQ_050	= 50;	-- Board the Enterprise and defeat Nael van Darnus.
SEQ_060	= 60;	-- Meet Cid in the clearing (set by the battle's director).
SEQ_070	= 70;	-- Return to the Lotus Stand.

-- Quest Actors
KINNISON				= 1001430;	-- sentry before the Lotus Stand
KAN_E_SENNA				= 1001569;
MERLWYB					= 1001568;
RAUBAHN					= 1060008;
CID						= 1001572;
GREGORY					= 1002046;	-- the Enterprise's steward
YSHTOLA					= 1000001;
PAPALYMO				= 1000010;
THANCRED				= 1000185;
YDA						= 1002000;

-- Triggers
CAMP_GLORY_LOOKOUT		= 1090343;	-- south and east of Camp Glory, under the floating isles

-- Each nation's officer, leader and marshal, and the talks they give.
NATIONS = {
	[1] = {	-- the Maelstrom
		officer = 1500199, start = "processEventStartLim", follow = "processEventGuincum",
		leader = MERLWYB, marshal = 1060024, marshalEvent = "processEventEynzahr",
		company = 1,
	},
	[2] = {	-- the Order of the Twin Adder
		officer = 1500200, start = "processEventStartGri", follow = "processEventFulke",
		leader = KAN_E_SENNA, marshal = 1060025, marshalEvent = "processEventSwethryk",
		company = 2,
	},
	[3] = {	-- the Immortal Flames
		officer = 1500198, start = "processEventStartUld", follow = "processEventAubrey",
		leader = RAUBAHN, marshal = 1060026, marshalEvent = "processEventEline",
		company = 3,
	},
};

-- The leaders at the council: orders to scout, orders to strike, and after.
-- Each talk takes the nation: the other leaders say a few words instead.
LEADERS = {
	[MERLWYB] = { "processEventMerlwyb1", "processEventMerlwyb2", "processEventMerlwyb3" },
	[KAN_E_SENNA] = { "processEventSenna01", "processEventSenna02", "processEventSenna03" },
	[RAUBAHN] = { "processEventRaubahn1", "processEventRaubahn2", "processEventRaubahn3" },
};

ARCHONS = {
	[YSHTOLA] = "processEventShtola",
	[PAPALYMO] = "processEventPapalymo",
	[THANCRED] = "processEventThancred",
	[YDA] = "processEventYda",
};

-- Places
LOTUS_STAND				= {206, -338.5, 6.82, -1701.0, -1.57};

-- Facing van Darnus: Disciples of War or Magic at level 45, as Cid tells
-- it. The server has no party state for scripts yet, so only the level and
-- the discipline are checked.
ENTRY_LEVEL				= 45;
RAID_CONTENT			= 15;		-- Rivenroad in the client's raid list
BOARD					= 1;		-- Gregory's menu: board the Enterprise

-- Rewards (the client's reward sheet row: EXP tier 6 in slot 1, seals in slot 5)
REWARD_EXP				= 1322;
REWARD_SEALS			= 6000;

local function nation()
	return NATIONS[NATION];
end

local function warpTo(player, place)
	GetWorldManager():DoZoneChange(player, place[1], nil, 0, 15, place[2], place[3], place[4], place[5]);
end

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	local n = nation();
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(n.officer, QFLAG_TALK);
		return;
	end

	quest:SetENpc(n.officer);
	quest:SetENpc(n.marshal);
	if (sequence == SEQ_000 or sequence == SEQ_030 or sequence == SEQ_070) then
		quest:SetENpc(KINNISON, QFLAG_TALK);
	end
	if (sequence == SEQ_010 or sequence == SEQ_030) then
		quest:SetENpc(n.leader, QFLAG_TALK);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(CAMP_GLORY_LOOKOUT, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_040 or sequence == SEQ_060) then
		quest:SetENpc(CID, QFLAG_TALK);
	elseif (sequence == SEQ_050) then
		quest:SetENpc(GREGORY, QFLAG_TALK);
	end
	if (sequence >= SEQ_010 and sequence ~= SEQ_020) then
		for leader in pairs(LEADERS) do
			if (leader ~= n.leader or (sequence ~= SEQ_010 and sequence ~= SEQ_030)) then
				quest:SetENpc(leader);
			end
		end
		if (sequence ~= SEQ_040 and sequence ~= SEQ_060) then
			quest:SetENpc(CID);
		end
		for archon in pairs(ARCHONS) do
			quest:SetENpc(archon);
		end
	end
end

-- Only Disciples of War or Magic at the entry level board the Enterprise.
local function mayEnter(player)
	return (player:IsDiscipleOfWar() or player:IsDiscipleOfMagic())
		and player:GetHighestLevel() >= ENTRY_LEVEL;
end

-- Which of a leader's talks fits this point of the quest.
local function leaderTalk(sequence)
	if (sequence < SEQ_030) then return 1 end
	if (sequence < SEQ_040) then return 2 end
	return 3;
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();
	local n = nation();

	if (sequence == SEQ_ACCEPT and classId == n.officer) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, n.start);
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (classId == n.officer) then
		callClientFunction(player, "delegateEvent", player, quest, n.follow);
	elseif (classId == n.marshal) then
		callClientFunction(player, "delegateEvent", player, quest, n.marshalEvent, NATION);

	-- Kinnison: to the council, back from Coerthas, and the alliance's thanks
	elseif (classId == KINNISON and (sequence == SEQ_000 or sequence == SEQ_030)) then
		local talk = sequence == SEQ_000 and "processEventKinnison01" or "processEventKinnison02";
		if (callClientFunction(player, "delegateEvent", player, quest, talk) == 1) then
			if (sequence == SEQ_000) then
				quest:StartSequence(SEQ_010);
			end
			player:EndEvent();
			warpTo(player, LOTUS_STAND);
			return;
		end
	elseif (classId == KINNISON and sequence == SEQ_070) then
		-- the Lotus Stand cheers its champion (gc010750); the quest is done
		if (callClientFunction(player, "delegateEvent", player, quest, "processEventKinnison03", NATION) == 1) then
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 5);
			player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
			player:AddSeals(n.company, REWARD_SEALS);
			player:EndEvent();
			player:CompleteQuest(quest);
			warpTo(player, LOTUS_STAND);
			return;
		end

	-- The council
	elseif (classId == n.leader and sequence == SEQ_010) then
		-- scout south and east of Camp Glory
		callClientFunction(player, "delegateEvent", player, quest, LEADERS[classId][1], NATION);
		quest:StartSequence(SEQ_020);
	elseif (classId == n.leader and sequence == SEQ_030) then
		-- assault the floating isle; ask Cid how
		callClientFunction(player, "delegateEvent", player, quest, LEADERS[classId][2], NATION);
		quest:StartSequence(SEQ_040);
	elseif (LEADERS[classId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, LEADERS[classId][leaderTalk(sequence)], NATION);
	elseif (ARCHONS[classId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, ARCHONS[classId]);

	-- Cid and the Enterprise
	elseif (classId == CID and sequence == SEQ_040) then
		-- Bozja, the Enterprise, and the terms of boarding
		callClientFunction(player, "delegateEvent", player, quest, "processEventCid03", NATION, RAID_CONTENT);
		quest:StartSequence(SEQ_050);
	elseif (classId == CID and sequence == SEQ_060) then
		-- van Darnus is dead and Dalamud stays aloft
		callClientFunction(player, "delegateEvent", player, quest, "processEventCid04", NATION);
		quest:StartSequence(SEQ_070);
	elseif (classId == CID) then
		local talk = "processEventCid01";
		if (sequence >= SEQ_050) then
			talk = "processEventCid02";
		end
		callClientFunction(player, "delegateEvent", player, quest, talk);
	elseif (classId == GREGORY and sequence == SEQ_050) then
		if (callClientFunction(player, "delegateEvent", player, quest, "processEventStewart", NATION, RAID_CONTENT) == BOARD
				and mayEnter(player)) then
			-- Cid asks once more whether you will fly with him
			callClientFunction(player, "delegateEvent", player, quest, "processEventNq2", NATION);
			player:EndEvent();
			enterDungeon(player, "rivenroad");
			return;
		end
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onPush(player, quest, npc)
	if (npc:GetActorClassId() == CAMP_GLORY_LOOKOUT and quest:GetSequence() == SEQ_020) then
		-- the floating isle, and Dalamud's fiery answer
		callClientFunction(player, "delegateEvent", player, quest, "processEventNq1");
		quest:StartSequence(SEQ_030);
	end
	player:EndEvent();
	quest:UpdateENPCs();
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
