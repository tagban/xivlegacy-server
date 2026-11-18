require ("global")
require ("quest")

--[[

Quest Script (shared by the three nations)

Name: 	Don't Hate the Messenger
Code: 	Gcl105 / Gcg105 / Gcu105
Id: 	111431 / 111631 / 111831
Prereq: In for Garuda Wakening (Gc?104), a sworn member of the company
		(company_gate in quest_offers.rs).

A Garlean stronghold, Castrum Novum, has risen in Mor Dhona, and Kan-E-Senna
calls on the three nations to remake the Eorzean Alliance. Your officer sends
you to the Lotus Stand (the sentry Kinnison lets you through), where Cid
Garlond names the stronghold and the Elder Seedseer gives you her terms. You
carry them to the other two leaders: Limsa Lominsa and Gridania go to Admiral
Merlwyb (Zanthael's lift) and then Flame General Raubahn (Mumutano at the
Fragrant Chamber); Ul'dah goes to Raubahn first. Each balks, and a messenger
sends you to Cid southwest of Camp Brittlebark. Garleans guard the imperial
warship his Ironworks brought down; one carries the key to its strongbox,
and opening it brings Gaius van Baelsar (cut scene gc010610) and the
Castrum Novum schematics. Cid sends you to the council at Stillglade Fane:
your company's Archon asks whether you are ready, the leaders forge the
alliance (gc010620), and word comes that the lunar transmitter is working.
Your nation's leader sends you to your marshal for the reward.

The client runs one script for all three quests (Gcl105; Gcg105 and Gcu105
are empty stubs); its talks take the nation as their argument. Each nation's
quest script sets NATION and loads this one. Seed 150 holds the cast, the
strongbox and the Garleans at the wreck.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Travel to the Lotus Stand by way of the clearing before it.
SEQ_005	= 5;	-- Speak with Cid at the Lotus Stand.
SEQ_010	= 10;	-- Hear Kan-E-Senna's proposal.
SEQ_015	= 15;	-- Hear Cid's thoughts once more.
SEQ_020	= 20;	-- Bring the terms to the first leader.
SEQ_025	= 25;	-- Bring both sets of terms to the second leader.
SEQ_030	= 30;	-- Hear the messenger's words.
SEQ_035	= 35;	-- Find Cid southwest of Camp Brittlebark.
SEQ_040	= 40;	-- Search the wreck; defeat the Garleans guarding it.
SEQ_045	= 45;	-- Open the strongbox.
SEQ_050	= 50;	-- Bring the schematics to Cid.
SEQ_055	= 55;	-- Speak with your Archon before the council.
SEQ_060	= 60;	-- Speak with your nation's leader.
SEQ_065	= 65;	-- Claim your reward from your marshal.

-- Quest Actors
KINNISON				= 1001430;	-- sentry before the Lotus Stand
KAN_E_SENNA				= 1001569;
CID						= 1001572;
MERLWYB					= 1001568;
RAUBAHN					= 1060008;
ZANTHAEL				= 1000351;	-- the Admiral's Lift
MUMUTANO				= 1001423;	-- the Fragrant Chamber's door
DYRFHUND				= 1001921;	-- stateroom guard (stands in for Augustine)
EBRELNAUX				= 1060011;
SAELBMOHT				= 1001732;
YSHTOLA					= 1000001;
PAPALYMO				= 1000010;
THANCRED				= 1000185;
URIANGER				= 1500204;
YDA						= 1002000;

-- Each nation's officer, Archon, leader, marshal, and the order the
-- leaders are visited in.
NATIONS = {
	[1] = {	-- the Maelstrom
		officer = 1500199, start = "processEventStartLim", follow = "processEventGuincum",
		archon = YSHTOLA, archonEvent = "processEventShtola1", archonAfter = "processEventShtola2",
		leader = MERLWYB, marshal = 1060024, marshalEvent = "processEventEynzahr3",
		route = { MERLWYB, RAUBAHN },
		company = 1,
	},
	[2] = {	-- the Order of the Twin Adder
		officer = 1500200, start = "processEventStartGri", follow = "processEventFulke",
		archon = PAPALYMO, archonEvent = "processEventPapalymo01", archonAfter = "processEventPapalymo03",
		leader = KAN_E_SENNA, marshal = 1060025, marshalEvent = "processEventSwethryk04",
		route = { MERLWYB, RAUBAHN },
		company = 2,
	},
	[3] = {	-- the Immortal Flames
		officer = 1500198, start = "processEventStartUld", follow = "processEventAubrey",
		archon = THANCRED, archonEvent = "processEventThancred1", archonAfter = "processEventThancred2",
		leader = RAUBAHN, marshal = 1060026, marshalEvent = "processEventEline3",
		route = { RAUBAHN, MERLWYB },
		company = 3,
	},
};

-- The leaders' audiences: who lets you in, and the talks before, during and
-- after the council.
LEADERS = {
	[MERLWYB] = { door = ZANTHAEL, doorEvent = "processEventZanthael1", place = {230, -621.0, 43.0, -67.0, 1.57},
		terms = "processEventMerlwyb1", termsAfter = "processEventMerlwyb2",
		council = "processEventMerlwyb3", councilAfter = "processEventMerlwyb4" },
	[RAUBAHN] = { door = MUMUTANO, doorEvent = "processEventMumutano01", place = {209, -102.0, 223.8, 201.0, 0.0},
		terms = "processEventRaubahn1", termsAfter = "processEventRaubahn2",
		council = "processEventRaubahn3", councilAfter = "processEventRaubahn4" },
	[KAN_E_SENNA] = { place = {206, -338.5, 6.82, -1701.0, -1.57},
		council = "processEventSenna05", councilAfter = "processEventSenna06" },
};

-- The messenger's words wait at the door of the last audience.
MESSENGER = {
	[RAUBAHN] = { npc = MUMUTANO, event = "processEventWaguda2" },
	[MERLWYB] = { npc = DYRFHUND, event = "processEventAugustine2", exit = {133, -437.0, 21.0, 178.0, 0.0} },	-- down the lift
};

-- Places
LOTUS_STAND				= {206, -338.5, 6.82, -1701.0, -1.57};

-- Triggers
STRONGBOX				= 1090341;	-- by the fallen warship in Mor Dhona

-- The Garleans at the wreck (open world); three must fall.
GARLEANS				= { [2280001] = true, [2280003] = true, [2280006] = true };
GARLEANS_NEEDED			= 3;
KILL_COUNTER			= 0;

-- Key items
STRONGBOX_KEY			= 11000434;
SCHEMATICS				= 11000433;

-- Rewards (the client's reward sheet row: EXP tier 7 in slot 1, seals in slot 5)
REWARD_EXP				= 1541;
REWARD_SEALS			= 2000;

local function nation()
	return NATIONS[NATION];
end

-- The leader the terms go to at this sequence (SEQ_020 or SEQ_025).
local function routeLeader(sequence)
	local n = nation();
	if (sequence == SEQ_020) then return n.route[1] end
	if (sequence == SEQ_025) then return n.route[2] end
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

	quest:SetENpc(n.officer, QFLAG_NONE);
	if (sequence == SEQ_000) then
		quest:SetENpc(KINNISON, QFLAG_TALK);
	elseif (sequence == SEQ_005 or sequence == SEQ_015) then
		quest:SetENpc(CID, QFLAG_TALK);
		quest:SetENpc(KAN_E_SENNA);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(KAN_E_SENNA, QFLAG_TALK);
		quest:SetENpc(CID);
	elseif (sequence == SEQ_020 or sequence == SEQ_025) then
		local leader = routeLeader(sequence);
		quest:SetENpc(leader, QFLAG_TALK);
		quest:SetENpc(LEADERS[leader].door, QFLAG_TALK);
		quest:SetENpc(KAN_E_SENNA);
		quest:SetENpc(CID);
	elseif (sequence == SEQ_030) then
		local m = MESSENGER[n.route[2]];
		quest:SetENpc(m.npc, QFLAG_TALK);
		quest:SetENpc(n.route[1]);
		quest:SetENpc(n.route[2]);
	elseif (sequence == SEQ_035 or sequence == SEQ_050) then
		quest:SetENpc(CID, QFLAG_TALK);
		quest:SetENpc(EBRELNAUX);
		quest:SetENpc(SAELBMOHT);
	elseif (sequence == SEQ_040 or sequence == SEQ_045) then
		quest:SetENpc(STRONGBOX, QFLAG_PUSH, false, true);
		quest:SetENpc(CID);
		quest:SetENpc(EBRELNAUX);
		quest:SetENpc(SAELBMOHT);
	elseif (sequence == SEQ_055) then
		quest:SetENpc(n.archon, QFLAG_TALK);
		quest:SetENpc(CID);
		for _, archon in ipairs({YSHTOLA, PAPALYMO, THANCRED, URIANGER, YDA}) do
			if (archon ~= n.archon) then quest:SetENpc(archon) end
		end
	elseif (sequence == SEQ_060) then
		quest:SetENpc(n.leader, QFLAG_TALK);
		quest:SetENpc(CID);
		quest:SetENpc(n.archon);
	elseif (sequence == SEQ_065) then
		quest:SetENpc(n.marshal, QFLAG_REWARD);
		quest:SetENpc(n.leader);
		quest:SetENpc(CID);
		quest:SetENpc(n.archon);
	end
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

	elseif (classId == KINNISON and sequence == SEQ_000) then
		-- "Proceed to the Lotus Stand?" (1 = yes)
		if (callClientFunction(player, "delegateEvent", player, quest, "processEventKinnison", NATION) == 1) then
			quest:StartSequence(SEQ_005);
			player:EndEvent();
			warpTo(player, LOTUS_STAND);
			return;
		end

	-- The Lotus Stand
	elseif (classId == CID and sequence == SEQ_005) then
		-- Castrum Novum and the lunar transmitter
		callClientFunction(player, "delegateEvent", player, quest, "processEventCid01", NATION);
		quest:StartSequence(SEQ_010);
	elseif (classId == KAN_E_SENNA and sequence == SEQ_005) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventSenna01", NATION);
	elseif (classId == CID and sequence == SEQ_010) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventCid02");
	elseif (classId == KAN_E_SENNA and sequence == SEQ_010) then
		-- her terms, and the letter (either answer carries it)
		callClientFunction(player, "delegateEvent", player, quest, "processEventSenna02", NATION);
		quest:StartSequence(SEQ_015);
	elseif (classId == CID and sequence == SEQ_015) then
		-- should the alliance be remade?
		callClientFunction(player, "delegateEvent", player, quest, "processEventCid03", NATION);
		quest:StartSequence(SEQ_020);

	-- The audiences
	elseif ((sequence == SEQ_020 or sequence == SEQ_025)
			and classId == LEADERS[routeLeader(sequence)].door) then
		local leader = LEADERS[routeLeader(sequence)];
		if (callClientFunction(player, "delegateEvent", player, quest, leader.doorEvent) == 1) then
			player:EndEvent();
			warpTo(player, leader.place);
			return;
		end
	elseif ((sequence == SEQ_020 or sequence == SEQ_025) and classId == routeLeader(sequence)) then
		callClientFunction(player, "delegateEvent", player, quest, LEADERS[classId].terms, NATION);
		quest:StartSequence(sequence == SEQ_020 and SEQ_025 or SEQ_030);
	elseif (sequence == SEQ_030 and classId == MESSENGER[n.route[2]].npc) then
		-- Mor Dhona, southwest of Camp Brittlebark; then "Exit?" (1 = yes)
		local leave = callClientFunction(player, "delegateEvent", player, quest, MESSENGER[n.route[2]].event, NATION);
		quest:StartSequence(SEQ_035);
		if (leave == 1 and MESSENGER[n.route[2]].exit ~= nil) then
			player:EndEvent();
			warpTo(player, MESSENGER[n.route[2]].exit);
			return;
		end

	-- Mor Dhona
	elseif (classId == CID and sequence == SEQ_035) then
		-- the warship his Ironworks brought down
		callClientFunction(player, "delegateEvent", player, quest, "processEventCid05", NATION);
		quest:GetData():SetCounter(KILL_COUNTER, 0);
		quest:StartSequence(SEQ_040);
	elseif (classId == CID and (sequence == SEQ_040 or sequence == SEQ_045)) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventCid06");
	elseif (classId == CID and sequence == SEQ_050) then
		-- Gaius, the schematics, and the council
		callClientFunction(player, "delegateEvent", player, quest, "processEventCid07");
		quest:StartSequence(SEQ_055);
	elseif (classId == EBRELNAUX) then
		callClientFunction(player, "delegateEvent", player, quest, sequence >= SEQ_050 and "processEventEbrelnaux2" or "processEventEbrelnaux1");
	elseif (classId == SAELBMOHT) then
		callClientFunction(player, "delegateEvent", player, quest, sequence >= SEQ_050 and "processEventSaelbmoht2" or "processEventSaelbmoht1");

	-- The council
	elseif (classId == n.archon and sequence == SEQ_055) then
		-- "Are you ready?", then the council itself
		callClientFunction(player, "delegateEvent", player, quest, n.archonEvent, NATION);
		callClientFunction(player, "delegateEvent", player, quest, "processEventNq", NATION);
		quest:StartSequence(SEQ_060);
		player:EndEvent();
		warpTo(player, LEADERS[n.leader].place);
		return;
	elseif (classId == URIANGER and sequence == SEQ_055) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventUrianger");
	elseif (classId == YDA and sequence == SEQ_055) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventYda");
	elseif (classId == n.leader and sequence == SEQ_060) then
		-- the transmitter is working; to Mor Dhona
		callClientFunction(player, "delegateEvent", player, quest, LEADERS[n.leader].council);
		quest:StartSequence(SEQ_065);
	elseif (classId == n.marshal and sequence == SEQ_065) then
		callClientFunction(player, "delegateEvent", player, quest, n.marshalEvent);
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 5);
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(SCHEMATICS, 1);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddSeals(n.company, REWARD_SEALS);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	elseif (classId == n.leader and sequence == SEQ_065) then
		callClientFunction(player, "delegateEvent", player, quest, LEADERS[n.leader].councilAfter);
	elseif (classId == n.archon and sequence >= SEQ_060) then
		callClientFunction(player, "delegateEvent", player, quest, n.archonAfter);
	elseif (classId == CID and sequence >= SEQ_060) then
		callClientFunction(player, "delegateEvent", player, quest, sequence == SEQ_060 and "processEventCid09" or "processEventCid10");

	-- After the terms are heard
	elseif (classId == CID and sequence >= SEQ_020 and sequence <= SEQ_030) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventCid04", NATION);
	elseif (classId == KAN_E_SENNA and sequence >= SEQ_015 and sequence <= SEQ_030) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventSenna03");
	elseif (LEADERS[classId] ~= nil and LEADERS[classId].termsAfter ~= nil and sequence >= SEQ_025 and sequence <= SEQ_030) then
		callClientFunction(player, "delegateEvent", player, quest, LEADERS[classId].termsAfter, NATION);
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onPush(player, quest, npc)
	local sequence = quest:GetSequence();

	if (npc:GetActorClassId() == STRONGBOX) then
		if (sequence == SEQ_045) then
			-- the strongbox opens, and Gaius van Baelsar steps out of the smoke
			callClientFunction(player, "delegateEvent", player, quest, "processEventNq1", NATION, 0);
			player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(STRONGBOX_KEY, 1);
			player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(SCHEMATICS, 1, 1);
			quest:StartSequence(SEQ_050);
		elseif (sequence == SEQ_040) then
			-- locked
			callClientFunction(player, "delegateEvent", player, quest, "processEventContainer");
		end
	end
	player:EndEvent();
	quest:UpdateENPCs();
end

-- One of the Garleans guarding the wreck carries the strongbox's key.
function onKillBNpc(player, quest, bnpc)
	if (quest:GetSequence() ~= SEQ_040 or not GARLEANS[bnpc]) then
		return;
	end
	-- the counter reads back stale within this hook: count this kill by hand
	local killed = quest:GetData():GetCounter(KILL_COUNTER) + 1;
	quest:GetData():IncCounter(KILL_COUNTER);
	if (killed >= GARLEANS_NEEDED) then
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(STRONGBOX_KEY, 1, 1);
		quest:StartSequence(SEQ_045);
	end
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
