require ("global")
require ("quest")
require ("dungeon")

--[[

Quest Script

Name: 	Imperial Devices
Code: 	Com5g0
Id: 	111610
Prereq: A sworn member of the Order of the Twin Adder (company_gate in quest_offers.rs).

Kan-E-Senna has heard an impure voice in the Thousand Maws of Toto-Rak,
driving beasts to frenzy, and the first Wood Wailers sent in came back
scattered and ill, many saved by a Padjal no guard let in. Fulke sends you
in with a party. Bloisirant at the entrance, in the South Shroud's Silent
Arbor, asks you to find that Padjal. In the Maws' last chamber he is
Seedseer A-Ruhn-Senna, resting with the moogles he came to save; he hands
you a piece the moogles pulled off the imperial device there. The device
takes you back out. Bloisirant reports the Seedseer found, and Fulke sends
the piece on to the Garlond Ironworks.

The client script (com5g0) names the events. Seed 137 gives A-Ruhn-Senna
his class; the dungeon content script spawns him beside the moogles and the
device (Com5u0, seed 136).

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Speak with Bloisirant at the Maws' entrance.
SEQ_010	= 10;	-- Find the Padjal in the Thousand Maws of Toto-Rak.
SEQ_020	= 20;	-- Leave the Maws and speak with Bloisirant.
SEQ_030	= 30;	-- Report to Fulke.

-- Quest Actors
FULKE					= 1500200;
BLOISIRANT				= 1001150;
A_RUHN_SENNA			= 1001571;
KUPCHA_KUPA				= 1001938;	-- the moogle who pulled the piece off
PUKNI_PAKK				= 1001937;	-- "A-Ruhn saved us, kupo!"
PUKNO_POKI				= 1001936;	-- "If he hadn't come..."
TRANSMITTER				= 1002063;	-- the imperial device in the last chamber

-- Key item: the piece of the device
RECORDING_PLATE			= 11000260;

-- Entry to the Maws, as in Com5u0: only the level and the discipline are
-- checked (no party state for scripts yet).
ENTRY_LEVEL				= 25;
PARTY_MAX				= 4;
TIME_LIMIT				= 60;		-- minutes, as Bloisirant tells it

-- Kupcha Kupa remembers you if another company's Imperial Devices brought
-- you to him first.
OTHER_IMPERIAL_DEVICES	= {111410, 111810};

-- Rewards (the client's reward sheet row: EXP tier 8 in slot 1, seals in slot 5)
REWARD_EXP				= 1760;
REWARD_SEALS			= 1000;
COMPANY					= 2;

-- The other moogles' lines, any time in the Maws.
MOOGLE_TALK = {
	[PUKNI_PAKK]		= "followEvent_030",
	[PUKNO_POKI]		= "followEvent_040",
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(FULKE, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(BLOISIRANT, QFLAG_TALK);
		quest:SetENpc(FULKE);
	elseif (sequence == SEQ_010 or sequence == SEQ_020) then
		quest:SetENpc(BLOISIRANT, QFLAG_TALK);
		quest:SetENpc(A_RUHN_SENNA, sequence == SEQ_010 and QFLAG_TALK or QFLAG_NONE);
		quest:SetENpc(KUPCHA_KUPA);
		quest:SetENpc(PUKNI_PAKK);
		quest:SetENpc(PUKNO_POKI);
		quest:SetENpc(TRANSMITTER, QFLAG_TALK);
		quest:SetENpc(FULKE);
	elseif (sequence == SEQ_030) then
		quest:SetENpc(FULKE, QFLAG_REWARD);
		quest:SetENpc(BLOISIRANT);
		quest:SetENpc(TRANSMITTER, QFLAG_TALK);
	end
end

-- Only Disciples of War or Magic at the entry level go in.
local function mayEnter(player)
	return (player:IsDiscipleOfWar() or player:IsDiscipleOfMagic())
		and player:GetHighestLevel() >= ENTRY_LEVEL;
end

local function metKupchaKupa(player)
	for _, questId in ipairs(OTHER_IMPERIAL_DEVICES) do
		if (player:IsQuestCompleted(questId)) then
			return true;
		end
	end
	return false;
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();

	if (sequence == SEQ_ACCEPT and classId == FULKE) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventFULKEStart", ENTRY_LEVEL, PARTY_MAX, 0);
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (sequence < SEQ_030 and classId == FULKE) then
		callClientFunction(player, "delegateEvent", player, quest, "followEvent_000", ENTRY_LEVEL, PARTY_MAX, 0);
	elseif (sequence == SEQ_000 and classId == BLOISIRANT) then
		-- the Padjal the wounded swear by, and the Maws' rules
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010", TIME_LIMIT);
		quest:StartSequence(SEQ_010);
	elseif (sequence == SEQ_010 and classId == BLOISIRANT) then
		local enter = callClientFunction(player, "delegateEvent", player, quest, "processEvent_010_1");
		if (enter == 1) then
			if (not mayEnter(player)) then
				callClientFunction(player, "delegateEvent", player, quest, "menberCountUnderRange", ENTRY_LEVEL, PARTY_MAX);
			else
				player:EndEvent();
				enterDungeon(player, "totorak");
				return;
			end
		end
	elseif (sequence == SEQ_010 and classId == A_RUHN_SENNA) then
		-- the crystals' screams, the voice, and the piece too heavy to carry
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_020");
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(RECORDING_PLATE, 1, 1);
		quest:StartSequence(SEQ_020);
	elseif (sequence == SEQ_020 and classId == A_RUHN_SENNA) then
		callClientFunction(player, "delegateEvent", player, quest, "followEvent_020");
	elseif (classId == KUPCHA_KUPA) then
		local talk = metKupchaKupa(player) and "processEvent_030" or "processEvent_030_1";
		callClientFunction(player, "delegateEvent", player, quest, talk);
	elseif (MOOGLE_TALK[classId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, MOOGLE_TALK[classId]);
	elseif (classId == TRANSMITTER and player:GetZoneID() == DUNGEONS.totorak.zone) then
		-- the device's way back to the entrance
		player:EndEvent();
		leaveDungeon(player);
		return;
	elseif (sequence == SEQ_020 and classId == BLOISIRANT) then
		-- word from the Nest: the Padjal was Seedseer A-Ruhn-Senna
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_050");
		quest:StartSequence(SEQ_030);
	elseif (sequence == SEQ_030 and classId == BLOISIRANT) then
		callClientFunction(player, "delegateEvent", player, quest, "followEvent_050");
	elseif (sequence == SEQ_030 and classId == FULKE) then
		-- the woodsin, the device's purpose, and the piece for the Ironworks
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_060");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 5);
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(RECORDING_PLATE, 1);
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
