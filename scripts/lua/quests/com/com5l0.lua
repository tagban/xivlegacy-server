require ("global")
require ("quest")
require ("dungeon")

--[[

Quest Script

Name: 	Imperial Devices
Code: 	Com5l0
Id: 	111410
Prereq: A sworn member of the Maelstrom (company_gate in quest_offers.rs).

The Maelstrom wants the power cells off the magitek devices the Garleans
have been assembling in the Thousand Maws of Toto-Rak, for the battleships
Naldiq & Vymelli's and the Garlond Ironworks are building. The Wood Wailers
have sealed the Maws, so Guincum sends you to Brother Zerig at the
Stillglade Fane with a petition from Cid. Zerig lets you in, if you carry an
urn with an earth elemental to where the Empire has tampered with the
dungeon. Bloisirant at the entrance, in the South Shroud's Silent Arbor,
lets you pass on seeing the urn. In the last chamber Kupcha Kupa gives you
the cell he pulled off the device and takes the urn to free the angry
elemental himself. The device takes you back out. Bloisirant tells you of
Gridania's plan to forge crystals from the Maws' aether, and Guincum takes
the cell and the news.

The client script (com5l0) names the events. Seed 138 places Brother
Zerig; seed 136 and the dungeon content script hold Bloisirant, the moogles
and the device (Com5u0).

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Deliver the petition to Brother Zerig.
SEQ_005	= 5;	-- Speak with Bloisirant at the Maws' entrance.
SEQ_010	= 10;	-- Search the Thousand Maws of Toto-Rak.
SEQ_015	= 15;	-- Leave the Maws and speak with Bloisirant.
SEQ_020	= 20;	-- Report to Guincum.

-- Quest Actors
GUINCUM					= 1500199;
ZERIG					= 1000510;
BLOISIRANT				= 1001150;
KUPCHA_KUPA				= 1001938;	-- the moogle with the cell
PUKNI_PAKK				= 1001937;
PUKNO_POKI				= 1001936;
TRANSMITTER				= 1002063;	-- the imperial device in the last chamber

-- Key items
PETITION				= 11000267;	-- Stillglade Fane Petition, from Cid
SEALED_URN				= 11000268;	-- the earth elemental
BLACKENED_ACCUMULATOR	= 11000263;	-- the device's magitek cell

-- Entry to the Maws, as in Com5u0: only the level and the discipline are
-- checked (no party state for scripts yet).
ENTRY_LEVEL				= 25;
PARTY_MAX				= 4;
TIME_LIMIT				= 60;		-- minutes, as Bloisirant tells it

-- Kupcha Kupa remembers you if another company's Imperial Devices brought
-- you to him first.
OTHER_IMPERIAL_DEVICES	= {111610, 111810};

-- Rewards (the client's reward sheet row: EXP tier 8 in slot 1, seals in slot 5)
REWARD_EXP				= 1760;
REWARD_SEALS			= 1000;
COMPANY					= 1;

-- The Eorzean Alliance: the client has alternate lines for after it formed.
-- This server's story stands before it.
ALLIANCE				= 0;

-- Bloisirant's two greetings and his two accounts of the angered elemental;
-- the first of each (1) is for Gridanians and Wood Wailers.
BLOISIRANT_OUTSIDER		= 0;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(GUINCUM, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ZERIG, QFLAG_TALK);
		quest:SetENpc(GUINCUM);
	elseif (sequence == SEQ_005) then
		quest:SetENpc(BLOISIRANT, QFLAG_TALK);
		quest:SetENpc(ZERIG);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(BLOISIRANT, QFLAG_TALK);
		quest:SetENpc(KUPCHA_KUPA, QFLAG_TALK);
		quest:SetENpc(PUKNI_PAKK);
		quest:SetENpc(PUKNO_POKI);
		quest:SetENpc(TRANSMITTER, QFLAG_TALK);
		quest:SetENpc(ZERIG);
	elseif (sequence == SEQ_015) then
		quest:SetENpc(BLOISIRANT, QFLAG_TALK);
		quest:SetENpc(KUPCHA_KUPA);
		quest:SetENpc(PUKNI_PAKK);
		quest:SetENpc(PUKNO_POKI);
		quest:SetENpc(TRANSMITTER, QFLAG_TALK);
		quest:SetENpc(ZERIG);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(GUINCUM, QFLAG_REWARD);
		quest:SetENpc(BLOISIRANT);
		quest:SetENpc(ZERIG);
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

	if (sequence == SEQ_ACCEPT and classId == GUINCUM) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventGUINCUMStart", PARTY_MAX, ALLIANCE);
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
			player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(PETITION, 1, 1);
		end
	elseif (sequence < SEQ_020 and classId == GUINCUM) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_000");
	elseif (sequence == SEQ_000 and classId == ZERIG) then
		-- Cid's petition, the woodsin, and the urn
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_005", PARTY_MAX, ALLIANCE);
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(PETITION, 1);
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(SEALED_URN, 1, 1);
		quest:StartSequence(SEQ_005);
	elseif ((sequence == SEQ_005 or sequence == SEQ_010) and classId == ZERIG) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_005_01", PARTY_MAX, ENTRY_LEVEL);
	elseif (sequence >= SEQ_015 and classId == ZERIG) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_020_1");
	elseif (sequence == SEQ_005 and classId == BLOISIRANT) then
		-- the urn he did not expect so soon, and the Maws' rules
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010", BLOISIRANT_OUTSIDER, TIME_LIMIT);
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
		-- the cell off the device, and the elemental he will free
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_015", metKupchaKupa(player) and 1 or 0);
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(SEALED_URN, 1);
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(BLACKENED_ACCUMULATOR, 1, 1);
		quest:StartSequence(SEQ_015);
	elseif (sequence >= SEQ_015 and classId == KUPCHA_KUPA) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_015_1");
	elseif (classId == PUKNI_PAKK or classId == PUKNO_POKI) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_015_2");
	elseif (classId == TRANSMITTER and player:GetZoneID() == DUNGEONS.totorak.zone) then
		-- the device's way back to the entrance
		player:EndEvent();
		leaveDungeon(player);
		return;
	elseif (sequence == SEQ_015 and classId == BLOISIRANT) then
		-- the angered elemental, and Gridania's crystals
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_020", BLOISIRANT_OUTSIDER, ALLIANCE);
		quest:StartSequence(SEQ_020);
	elseif (sequence == SEQ_020 and classId == BLOISIRANT) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_020_2", BLOISIRANT_OUTSIDER);
	elseif (sequence == SEQ_020 and classId == GUINCUM) then
		-- the cell for the Ironworks, and the Maelstrom's way around the Empire
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_025", ALLIANCE);
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 5);
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(BLACKENED_ACCUMULATOR, 1);
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
