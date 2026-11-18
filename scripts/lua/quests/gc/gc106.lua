require ("global")
require ("quest")
require ("dungeon")

--[[

Quest Script (shared by the three nations)

Name: 	United We Stand
Code: 	Gcl106 / Gcg106 / Gcu106
Id: 	111432 / 111632 / 111832
Prereq: Don't Hate the Messenger (Gc?105), a sworn member of the company
		(company_gate in quest_offers.rs).

The Garleans have switched on the lunar transmitter at Castrum Novum. Your
officer sends you to Jagged Crest Cave, northwest of Camp Brittlebark in Mor
Dhona, where the three-nation army gathers. Flame Commander Ryder lays out the
plan over a map of the stronghold and sends you to Serpent Commander
Yarborough for the briefing. The cave's aetherial gate takes the assault
party into Castrum Novum: cut through its defenders and the magitek vanguard
and destroy the transmitter. Back at the cave your company's officer there
(Rhiki, Quinquerol or Ryder) sends you home: Zanthael's lift to the stateroom,
Kinnison to the Lotus Stand, or Mumutano to the Fragrant Chamber. Cid tells
of Nael van Darnus's parting words, your leader hears your report and gives
new orders, and your marshal pays the reward.

The client runs one script for all three quests (Gcl106; Gcg106 and Gcu106
are empty stubs); its talks take the nation as their argument. Each nation's
quest script sets NATION and loads this one. Seed 151 holds the cave's cast,
the gate, Cid beside Merlwyb and Raubahn, and Castrum Novum's defenders; the
assault runs as content (dungeon.lua "castrum", director
InstanceRaidBeaconBattle).

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Hear Commander Yarborough's briefing.
SEQ_010	= 10;	-- Enter Castrum Novum through the aetherial gate and destroy the transmitter.
SEQ_020	= 20;	-- Report to your nation's leader (set by the battle's director).
SEQ_030	= 30;	-- Hear your nation's leader.
SEQ_040	= 40;	-- Claim your reward from your marshal.

-- Quest Actors
RYDER					= 1001815;	-- Flame Commander Jakys Ryder
YARBOROUGH				= 1001808;	-- Serpent Commander Vevina Yarborough
RHIKI					= 1001810;	-- Storm Commander Rashaht Rhiki
QUINQUEROL				= 1001809;
CID						= 1001572;
MERLWYB					= 1001568;
KAN_E_SENNA				= 1001569;
RAUBAHN					= 1060008;
ZANTHAEL				= 1000351;	-- the Admiral's Lift
KINNISON				= 1001430;	-- sentry before the Lotus Stand
MUMUTANO				= 1001423;	-- the Fragrant Chamber's door
REYNER					= 1000140;
PESI					= 1000033;

-- Triggers
CAVE_GATE				= 1090342;	-- Jagged Crest Cave's aetherial gate

-- Each nation's officer, the commander who sends you home, the way in to
-- the leader, and the talks there.
NATIONS = {
	[1] = {	-- the Maelstrom
		officer = 1500199, hint = "processEvent_LimsaHint_Guincum_01",
		navi = RHIKI,
		door = ZANTHAEL, doorEvent = "processEvent_LimsaWarp_Zanthael_01", place = {230, -621.0, 43.0, -67.0, 1.57},
		leader = MERLWYB, leaderEvent = "processEvent_LimsaInstance_Merlwyb_01", leaderAfter = "processEvent_LimsaInstance_Merlwyb_02",
		marshal = 1060024, marshalBefore = "processEvent_LimsaInstance_Eynzahr_01", marshalEvent = "processEvent_LimsaInstance_Eynzahr_02",
		flavor = { [REYNER] = { "processEvent_LimsaInstance_Reyner_01", "processEvent_LimsaInstance_Reyner_02" } },
		company = 1,
	},
	[2] = {	-- the Order of the Twin Adder
		officer = 1500200, hint = "processEvent_GridaniaHint_Fulke_01",
		navi = QUINQUEROL,
		door = KINNISON, doorEvent = "processEvent_GridaniaWarp_Kinnison_01", place = {206, -338.5, 6.82, -1701.0, -1.57},
		leader = KAN_E_SENNA, leaderEvent = "processEvent_GridaniaInstance_Shinkan_01", leaderAfter = "processEvent_GridaniaInstance_Shinkan_02",
		marshal = 1060025, marshalBefore = "processEvent_GridaniaInstance_Swethryk_01", marshalEvent = "processEvent_GridaniaInstance_Swethryk_02",
		flavor = { [PESI] = { "processEvent_GridaniaInstance_Pesi_01", "processEvent_GridaniaInstance_Pesi_02" } },
		company = 2,
	},
	[3] = {	-- the Immortal Flames
		officer = 1500198, hint = "processEvent_UldahHint_Aubray_01",
		navi = RYDER,
		door = MUMUTANO, doorEvent = "processEvent_UldahWarp_Mumutano_01", place = {209, -102.0, 223.8, 201.0, 0.0},
		leader = RAUBAHN, leaderEvent = "processEvent_UldahInstance_Raubahn_01", leaderAfter = "processEvent_UldahInstance_Raubahn_02",
		marshal = 1060026, marshalBefore = "processEvent_UldahInstance_Eline_01", marshalEvent = "processEvent_UldahInstance_Eline_02",
		flavor = {},
		company = 3,
	},
};

-- Every company's commander at the cave has words once the transmitter falls.
NAVIS = {
	[RHIKI] = "processEvent_CommonNavi_Rashaht_01",
	[QUINQUEROL] = "processEvent_CommonNavi_Quinquerol_01",
	[RYDER] = "processEvent_CommonNavi_Jakys_01",
};

-- Storming Castrum Novum: Disciples of War or Magic at level 45, as the
-- briefing tells it. The server has no party state for scripts yet, so only
-- the level and the discipline are checked.
ENTRY_LEVEL				= 45;
RAID_CONTENT			= 13;		-- Castrum Novum in the client's raid list

-- Rewards (the client's reward sheet row: EXP tier 7 in slot 1, seals in slot 5)
REWARD_EXP				= 1541;
REWARD_SEALS			= 5000;

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
		quest:SetENpc(RYDER, QFLAG_TALK);
		quest:SetENpc(n.officer);
		return;
	end

	quest:SetENpc(n.officer);
	quest:SetENpc(n.marshal, sequence == SEQ_040 and QFLAG_REWARD or QFLAG_NONE);
	if (sequence == SEQ_000) then
		quest:SetENpc(YARBOROUGH, QFLAG_TALK);
		quest:SetENpc(RYDER);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(CAVE_GATE, QFLAG_PUSH, false, true);
		quest:SetENpc(YARBOROUGH);
		quest:SetENpc(RYDER);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(n.door, QFLAG_TALK);
		quest:SetENpc(CID, QFLAG_TALK);
		quest:SetENpc(n.leader);
		for navi in pairs(NAVIS) do
			quest:SetENpc(navi, navi == n.navi and QFLAG_TALK or QFLAG_NONE);
		end
	elseif (sequence >= SEQ_030) then
		quest:SetENpc(n.leader, sequence == SEQ_030 and QFLAG_TALK or QFLAG_NONE);
		quest:SetENpc(CID);
	end
	if (sequence >= SEQ_020) then
		for classId in pairs(n.flavor) do
			quest:SetENpc(classId);
		end
	end
end

-- Only Disciples of War or Magic at the entry level storm the stronghold.
local function mayEnter(player)
	return (player:IsDiscipleOfWar() or player:IsDiscipleOfMagic())
		and player:GetHighestLevel() >= ENTRY_LEVEL;
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();
	local n = nation();

	if (sequence == SEQ_ACCEPT and classId == RYDER) then
		-- the plan, over a map of the stronghold
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEvent_CommonStart_Jakys_01", NATION);
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (classId == n.officer) then
		callClientFunction(player, "delegateEvent", player, quest, n.hint);

	-- Jagged Crest Cave
	elseif (classId == YARBOROUGH and sequence <= SEQ_010) then
		-- the briefing (the content id fills in the entry terms)
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_CommonInfo_Vevina_01", NATION, RAID_CONTENT);
		if (sequence == SEQ_000) then
			quest:StartSequence(SEQ_010);
		end
	elseif (classId == RYDER and sequence <= SEQ_010) then
		-- "Have you forgotten everything you were told?" and the map again
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_CommonFollow_Jakys_01", NATION);
	elseif (NAVIS[classId] ~= nil and sequence >= SEQ_020) then
		callClientFunction(player, "delegateEvent", player, quest, NAVIS[classId], NATION);

	-- Home
	elseif (classId == n.door and sequence == SEQ_020) then
		if (callClientFunction(player, "delegateEvent", player, quest, n.doorEvent) == 1) then
			player:EndEvent();
			warpTo(player, n.place);
			return;
		end
	elseif (classId == CID and sequence == SEQ_020) then
		-- van Darnus's parting words
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_CommonInstance_Cid_01", NATION, NATION);
		quest:StartSequence(SEQ_030);
	elseif (classId == n.leader and sequence == SEQ_030) then
		-- your report, and new orders: assist Cid and Louisoix
		callClientFunction(player, "delegateEvent", player, quest, n.leaderEvent);
		quest:StartSequence(SEQ_040);
	elseif (classId == n.marshal and sequence == SEQ_040) then
		callClientFunction(player, "delegateEvent", player, quest, n.marshalEvent);
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 5);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddSeals(n.company, REWARD_SEALS);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	elseif (classId == n.marshal) then
		callClientFunction(player, "delegateEvent", player, quest, n.marshalBefore);
	elseif (classId == n.leader and sequence == SEQ_040) then
		callClientFunction(player, "delegateEvent", player, quest, n.leaderAfter);
	elseif (classId == CID) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_CommonInstance_Cid_02");
	elseif (n.flavor[classId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, n.flavor[classId][sequence >= SEQ_040 and 2 or 1]);
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onPush(player, quest, npc)
	local sequence = quest:GetSequence();

	if (npc:GetActorClassId() == CAVE_GATE and sequence == SEQ_010) then
		-- the aetherial gate (the client's own entry prompt)
		if (callClientFunction(player, "askEnterInstanceRaid", RAID_CONTENT) and mayEnter(player)) then
			player:EndEvent();
			enterDungeon(player, "castrum");
			return;
		end
	end
	player:EndEvent();
	quest:UpdateENPCs();
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
