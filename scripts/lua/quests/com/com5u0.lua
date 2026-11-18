require ("global")
require ("quest")
require ("dungeon")

--[[

Quest Script

Name: 	Imperial Devices
Code: 	Com5u0
Id: 	111810
Prereq: A sworn member of the Immortal Flames (company_gate in quest_offers.rs).

Beasts have been gathering in the Thousand Maws of Toto-Rak, and the squad
of Flames sent to find out why has fallen silent. Aubrey sends you after
them. Nuala of the Wood Wailers lets you into the Maws if you bring a party,
and Bloisirant at the entrance, in the South Shroud's Silent Arbor, tells
you the dungeon's rules. In its last chamber a moogle hands you a fallen
Flame's bracer and a piece he pulled off the imperial device there. The
device itself takes you back out, as Bloisirant says it will. Bloisirant
hears what you found; Aubrey takes the bracer for the fallen and sends the
piece to the Garlond Ironworks.

The client script (com5u0) names the events. Seed 136 holds Bloisirant, the
moogles and the device; the dungeon content script spawns the moogles and
the device into every copy of the Maws (the last chamber, by the lantern
huts).

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Obtain leave at the Wailing Barracks.
SEQ_005	= 5;	-- Speak with Bloisirant at the Maws' entrance.
SEQ_010	= 10;	-- Search the Thousand Maws of Toto-Rak.
SEQ_015	= 15;	-- Report to Aubrey.

-- Quest Actors
AUBREY					= 1500198;
NUALA					= 1000681;
BLOISIRANT				= 1001150;
KUPCHA_KUPA				= 1001938;	-- the moogle with the bracer and the piece
PUKNI_PAKK				= 1001937;	-- "A-Ruhn saved us!"
TRANSMITTER				= 1002063;	-- the imperial device in the last chamber

-- Key items: the fallen Flame's bracer and the device's piece
SHATTERED_GAUNTLET		= 11000261;
COOLING_PLATE			= 11000262;

-- Entry to the Maws: the level and party size the guards' lines name. The
-- server has no party state for scripts yet, so only the level and the
-- discipline are checked.
ENTRY_LEVEL				= 25;
PARTY_MAX				= 4;
TIME_LIMIT				= 60;		-- minutes, as Bloisirant tells it

-- Kupcha Kupa remembers you if another company's Imperial Devices brought
-- you to him first.
OTHER_IMPERIAL_DEVICES	= {111410, 111610};

-- Quest flags
FLAG_HEARD_BLOISIRANT	= 0;		-- his after-word, once

-- Rewards (the client's reward sheet row: EXP tier 8 in slot 1, seals in slot 5)
REWARD_EXP				= 1760;
REWARD_SEALS			= 1000;
COMPANY					= 3;

-- The Eorzean Alliance: the client has alternate lines for after it formed.
-- This server's story stands before it.
ALLIANCE				= 0;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(AUBREY, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(NUALA, QFLAG_TALK);
		quest:SetENpc(AUBREY);
	elseif (sequence == SEQ_005) then
		quest:SetENpc(BLOISIRANT, QFLAG_TALK);
		quest:SetENpc(NUALA);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(BLOISIRANT, QFLAG_TALK);
		quest:SetENpc(KUPCHA_KUPA, QFLAG_TALK);
		quest:SetENpc(PUKNI_PAKK);
		quest:SetENpc(TRANSMITTER, QFLAG_TALK);
		quest:SetENpc(NUALA);
	elseif (sequence == SEQ_015) then
		quest:SetENpc(AUBREY, QFLAG_REWARD);
		local heard = quest:GetData():GetFlag(FLAG_HEARD_BLOISIRANT);
		quest:SetENpc(BLOISIRANT, heard and QFLAG_NONE or QFLAG_TALK);
		quest:SetENpc(KUPCHA_KUPA);
		quest:SetENpc(PUKNI_PAKK);
		quest:SetENpc(TRANSMITTER, QFLAG_TALK);
	end
end

-- Only Disciples of War or Magic at the entry level go in.
local function mayEnter(player)
	return (player:IsDiscipleOfWar() or player:IsDiscipleOfMagic())
		and player:GetHighestLevel() >= ENTRY_LEVEL;
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();

	if (sequence == SEQ_ACCEPT and classId == AUBREY) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventAUBREYStart", ALLIANCE);
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (sequence == SEQ_000 and classId == AUBREY) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_000");
	elseif (sequence == SEQ_000 and classId == NUALA) then
		-- the Flames who would not wait, and the party you must bring
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_005", ENTRY_LEVEL, PARTY_MAX, ALLIANCE);
		quest:StartSequence(SEQ_005);
	elseif (sequence >= SEQ_005 and classId == NUALA) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_005_1", ENTRY_LEVEL, PARTY_MAX, ALLIANCE);
	elseif (sequence == SEQ_005 and classId == BLOISIRANT) then
		-- the bribe he refused, and the Maws' rules
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010", TIME_LIMIT);
		quest:StartSequence(SEQ_010);
	elseif (sequence == SEQ_010 and classId == BLOISIRANT) then
		local enter = callClientFunction(player, "delegateEvent", player, quest, "processEvent_010_01");
		if (enter == 1) then
			if (not mayEnter(player)) then
				callClientFunction(player, "delegateEvent", player, quest, "menberCountUnderRange", ENTRY_LEVEL, PARTY_MAX);
			else
				player:EndEvent();
				enterDungeon(player, "totorak");
				return;
			end
		end
	elseif (sequence == SEQ_010 and classId == KUPCHA_KUPA) then
		-- the dead Flames, the voice, and the piece of the device
		local met = player:IsQuestCompleted(OTHER_IMPERIAL_DEVICES[1]) or player:IsQuestCompleted(OTHER_IMPERIAL_DEVICES[2]);
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_015", met and 1 or 0);
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(SHATTERED_GAUNTLET, 1, 1);
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(COOLING_PLATE, 1, 1);
		quest:StartSequence(SEQ_015);
	elseif (sequence == SEQ_015 and classId == KUPCHA_KUPA) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_015_1");
	elseif (classId == PUKNI_PAKK) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_015_2");
	elseif (classId == TRANSMITTER and player:GetZoneID() == DUNGEONS.totorak.zone) then
		-- the device's way back to the entrance
		player:EndEvent();
		leaveDungeon(player);
		return;
	elseif (sequence == SEQ_015 and classId == BLOISIRANT) then
		if (not quest:GetData():GetFlag(FLAG_HEARD_BLOISIRANT)) then
			-- Garleans in the Maws, and silence among the Gridanians
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_020", ALLIANCE);
			quest:GetData():SetFlag(FLAG_HEARD_BLOISIRANT);
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_020_1");
		end
	elseif (sequence == SEQ_015 and classId == AUBREY) then
		-- the bracer kept for the fallen, the piece for the Ironworks
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_025", ALLIANCE);
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 5);
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(SHATTERED_GAUNTLET, 1);
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(COOLING_PLATE, 1);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddSeals(COMPANY, REWARD_SEALS);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onPush(player, quest, npc)
	player:EndEvent();
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
