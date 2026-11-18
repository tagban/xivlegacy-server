require ("global")
require ("quest")
require ("dungeon")

--[[

Quest Script (shared by the three nations)

Name: 	In for Garuda Wakening
Code: 	Gcl104 / Gcg104 / Gcu104
Id: 	111430 / 111630 / 111830
Prereq: Deus ex Machina / Shadow of the Raven / Careless Whispers (Gc?103),
		a sworn member of the company (company_gate in quest_offers.rs).

Fell winds batter Quarrymill in the South Shroud. Your officer sends you to
Louisoix at Apkallus Falls, who asks you to learn whence they blow. At
Quarrymill Garuda tears through the Wood Wailers (cut scene gc010410) and
leaves a plume behind. Louisoix enchants it into a key to the beastman
aetheryte at the north-east tip of Feathergorge, which carries you to the
Howling Eye. Garuda falls, Nael van Darnus gloats as Dalamud drinks her
crystals' power, and you are back at the gorge. Louisoix bids you take word
to Cid Garlond, who waits at your company's headquarters and sends you on to
your nation's leader: Merlwyb in the stateroom atop the Admiral's Lift
(gc01l410), Kan-E-Senna at Stillglade Fane (gc01g410), or Raubahn on the
Royal Promenade (gc01u410). Your officer pays the reward.

The client runs one script for all three quests (Gcl104; Gcg104 and Gcu104
are empty stubs), with hints, a talk after Cid and a closing event per
nation. Each nation's quest script sets NATION and loads this one. Seed 149
holds the Quarrymill cast, the two triggers, Cid in each headquarters and
Garuda; the battle runs as content (dungeon.lua "howling", director
InstanceRaidLesserGaruda).

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Discover whence the winds over Quarrymill blow.
SEQ_010	= 10;	-- Report to Louisoix.
SEQ_020	= 20;	-- Use the beastman aetheryte in Feathergorge and defeat Garuda.
SEQ_030	= 30;	-- Report to Louisoix (set by the battle's director).
SEQ_040	= 40;	-- Meet Cid Garlond at your company's headquarters.
SEQ_050	= 50;	-- Meet your nation's leader.
SEQ_060	= 60;	-- Report to your officer.

-- Quest Actors
LOUISOIX				= 1060022;
CID						= 1001572;
ETHELINDA				= 1001352;
HEDHEUE					= 1001353;

-- Each nation's officer and leader, and the talks the client gives them.
NATIONS = {
	[1] = {	-- the Maelstrom
		officer = 1500199, hint = "processEventHintLim", toCid = "processEventGuincum01", finish = "processEventGuincum03",
		leader = 1000351, leaderEvent = "processEventZanthael",	-- Zanthael and the Admiral's Lift
		after = { [1001568] = "processEventMerwyb", [1060024] = "processEventEynzahr" },
		company = 1,
	},
	[2] = {	-- the Order of the Twin Adder
		officer = 1500200, hint = "processEventHintGur", toCid = "processEventFulke01", finish = "processEventFulke03",
		leader = 1001569, leaderEvent = "processEventNQG",			-- Kan-E-Senna
		after = { [1001569] = "processEventSenna", [1060025] = "processEventSwethryk" },
		back = {206, -338.5, 6.82, -1701.0, -1.57},
		company = 2,
	},
	[3] = {	-- the Immortal Flames
		officer = 1500198, hint = "processEventHintUru", toCid = "processEventAubrey01", finish = "processEventAubrey03",
		leader = 1060008, leaderEvent = "processEventNQU",			-- Raubahn
		after = { [1060008] = "processEventRaubahn", [1060026] = "processEventEline" },
		back = {209, -102.0, 223.8, 201.0, 0.0},
		company = 3,
	},
};

-- Limsa Lominsa's stateroom shares Maelstrom Command's floor (zone 232):
-- the lift sets you down there after the Admiral's audience.
STATEROOM				= {232, 163.0, 0.0, -178.0, 1.57};

-- Triggers
QUARRYMILL				= 1090339;
FEATHERGORGE			= 1090340;	-- the beastman aetheryte

-- Key items
GARUDA_PLUME			= 11000431;	-- left behind at Quarrymill
TEMPEST_KEY				= 11000432;	-- Louisoix's enchanted plume

-- Facing Garuda: Disciples of War or Magic at level 45, as the briefing
-- tells it. The server has no party state for scripts yet, so only the
-- level and the discipline are checked.
ENTRY_LEVEL				= 45;
RAID_CONTENT			= 12;		-- the Howling Eye in the client's raid list

-- Rewards (the client's reward sheet row: EXP tier 7 in slot 1, seals in slot 5)
REWARD_EXP				= 1541;
REWARD_SEALS			= 2000;

local function nation()
	return NATIONS[NATION];
end

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	local n = nation();
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(LOUISOIX, QFLAG_TALK);
		return;
	end

	quest:SetENpc(n.officer, sequence == SEQ_060 and QFLAG_REWARD or QFLAG_NONE);
	if (sequence == SEQ_000) then
		quest:SetENpc(QUARRYMILL, QFLAG_PUSH, false, true);
		quest:SetENpc(LOUISOIX);
	elseif (sequence == SEQ_010 or sequence == SEQ_030) then
		quest:SetENpc(LOUISOIX, QFLAG_TALK);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(FEATHERGORGE, QFLAG_PUSH, false, true);
		quest:SetENpc(LOUISOIX);
	elseif (sequence == SEQ_040) then
		quest:SetENpc(CID, QFLAG_TALK);
		quest:SetENpc(LOUISOIX);
	elseif (sequence == SEQ_050) then
		quest:SetENpc(n.leader, QFLAG_TALK);
		quest:SetENpc(CID);
	end
	if (sequence <= SEQ_010) then
		quest:SetENpc(ETHELINDA);
		quest:SetENpc(HEDHEUE);
	end
	if (sequence == SEQ_060) then
		quest:SetENpc(CID);
		for classId in pairs(n.after) do
			quest:SetENpc(classId);
		end
	end
end

-- Only Disciples of War or Magic at the entry level face Garuda.
local function mayEnter(player)
	return (player:IsDiscipleOfWar() or player:IsDiscipleOfMagic())
		and player:GetHighestLevel() >= ENTRY_LEVEL;
end

local function warpBack(player, place)
	GetWorldManager():DoZoneChange(player, place[1], nil, 0, 15, place[2], place[3], place[4], place[5]);
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();
	local n = nation();

	if (sequence == SEQ_ACCEPT and classId == LOUISOIX) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (classId == n.officer and sequence == SEQ_060) then
		-- the company's thanks
		callClientFunction(player, "delegateEvent", player, quest, n.finish);
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 5);
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(TEMPEST_KEY, 1);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddSeals(n.company, REWARD_SEALS);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	elseif (classId == n.officer) then
		callClientFunction(player, "delegateEvent", player, quest, sequence >= SEQ_040 and n.toCid or n.hint);
	elseif (classId == ETHELINDA) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventEthelinda");
	elseif (classId == HEDHEUE) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventHedeue");
	elseif (classId == LOUISOIX and sequence == SEQ_010) then
		-- Garuda confirmed, the plume enchanted, and the way to the Howling Eye
		callClientFunction(player, "delegateEvent", player, quest, "processEventLouisoix01");
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(GARUDA_PLUME, 1);
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(TEMPEST_KEY, 1, 1);
		quest:StartSequence(SEQ_020);
	elseif (classId == LOUISOIX and sequence == SEQ_030) then
		-- Dalamud, the White Raven, and Cid Garlond
		callClientFunction(player, "delegateEvent", player, quest, "processEventLouisoix03");
		quest:StartSequence(SEQ_040);
	elseif (classId == LOUISOIX) then
		local talk = "processEventStartAfter";
		if (sequence >= SEQ_040) then
			talk = "processEventLouisoix04";
		elseif (sequence == SEQ_020) then
			talk = "processEventLouisoix02";
		end
		callClientFunction(player, "delegateEvent", player, quest, talk);
	elseif (classId == CID and sequence == SEQ_040) then
		-- the red moon draws closer, and your leader would see you
		callClientFunction(player, "delegateEvent", player, quest, "processEventCid");
		quest:StartSequence(SEQ_050);
	elseif (classId == n.leader and sequence == SEQ_050) then
		if (NATION == 1) then
			-- the Admiral's Lift (1 = ride) and her audience in the stateroom
			local ride = callClientFunction(player, "delegateEvent", player, quest, n.leaderEvent);
			if (ride == 1) then
				quest:StartSequence(SEQ_060);
				player:EndEvent();
				warpBack(player, STATEROOM);
				return;
			end
		else
			callClientFunction(player, "delegateEvent", player, quest, n.leaderEvent);
			quest:StartSequence(SEQ_060);
			player:EndEvent();
			warpBack(player, n.back);
			return;
		end
	elseif (n.after[classId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, n.after[classId]);
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onPush(player, quest, npc)
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();

	if (classId == QUARRYMILL and sequence == SEQ_000) then
		-- Garuda over Quarrymill
		callClientFunction(player, "delegateEvent", player, quest, "processEventNQ");
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(GARUDA_PLUME, 1, 1);
		quest:StartSequence(SEQ_010);
	elseif (classId == FEATHERGORGE and sequence == SEQ_020) then
		-- the beastman aetheryte (the client's own entry prompt)
		if (callClientFunction(player, "askEnterInstanceRaid", RAID_CONTENT) and mayEnter(player)) then
			player:EndEvent();
			enterDungeon(player, "howling");
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
