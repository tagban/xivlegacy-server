require ("global")
require ("quest")

--[[

Quest Script

Name:	The Sound of Silence
Code:	Bsm306
Id:	110322
Prereq: Level 36, Blacksmith

The siren scare has the smiths and armorers of Naldiq & Vymelli's fighting
over ore, and the Knights of the Barracuda want cannons to level the sirens'
island. Mimidoa would rather deal with the sirens himself: he hands you
sound-proofing rubber and has you make a bronze earplug mold from it and two
bronze ingots. With the mold done he rows you out to Hope's Bourn
(bsm30610), where the sirens' captives wait; the sirens strike (bsm30620)
and you wake back at the forge (bsm30630), where Mimidoa says the sirens are
dealt with. After a word with the forge, Mimidoa tells of his gramophone,
and the two "sirens" are revealed (bsm30640): 36,000 gil and 3,600
experience.

Simplified here: the island (the captives, the items to fetch and the
earplug prompts, the danceIsland_* functions) has no zone on this server,
so bsm30610, bsm30620 and bsm30630 play back to back. Mimidoa has a public
spawn on the forge balcony (31040). The mold has no recipe on this server
yet, so it is checked in the bag as it would come out of a synthesis.

Journal: steps 104-110 of the quest journal sheet (0B/45/08/1B).

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Speak with Mimidoa.
SEQ_005	= 5;   -- Make the earplug mold.
SEQ_030	= 30;  -- Back at the forge: hear the others out, then Mimidoa.

-- Actor Class Ids
ENPC_BODENOLF		= 1000144;
ENPC_MIMIDOA		= 1000176;
ENPC_IOFA			= 1000135;
ENPC_PFYNHAEMR		= 1000060;
ENPC_MZIMZIZI		= 1000061;
ENPC_CARRILAUT		= 1000062;
ENPC_MARTIALLAIS	= 1000134;
ENPC_SOSOZE			= 1000265;
ENPC_HIHINE			= 1000267;
ENPC_SATHZANT		= 1000338;
ENPC_GAUTZELIN		= 1000365;

ITEM_EARPLUG_MOLD	= 11000050; -- bronze earplug mold (crafted)
ITEM_RUBBER			= 11000052; -- sound-proofing rubber (key item from Mimidoa)

REWARD_GIL	= 36000;
REWARD_EXP	= 3600;

-- In front of Mimidoa on the forge balcony.
GUILD_ZONE = 230;
MIMIDOA_SPOT = { -482.25, 44.5, 405.92, -2.35 };

-- The forge's chatter; slots as in Bsm200 (8 and 9 are the twins, who turn
-- out to be the "sirens").
TALKS = {
	[SEQ_000] = {
		[ENPC_BODENOLF] = "processEvent003_2",
		[ENPC_CARRILAUT] = "processEvent003_3",
		[ENPC_MZIMZIZI] = "processEvent003_4",
		[ENPC_IOFA] = "processEvent003_5_1",
		[ENPC_MARTIALLAIS] = "processEvent003_6",
		[ENPC_PFYNHAEMR] = "processEvent003_7_1",
		[ENPC_SOSOZE] = "processEvent003_8",
		[ENPC_HIHINE] = "processEvent003_9",
		[ENPC_SATHZANT] = "processEvent003_10",
		[ENPC_GAUTZELIN] = "processEvent003_11",
	},
	[SEQ_005] = {
		[ENPC_BODENOLF] = "processEvent005_2",
		[ENPC_CARRILAUT] = "processEvent005_3",
		[ENPC_MZIMZIZI] = "processEvent005_4",
		[ENPC_IOFA] = "processEvent005_5",
	},
	[SEQ_030] = {
		[ENPC_BODENOLF] = "processEvent030_2",
		[ENPC_CARRILAUT] = "processEvent030_3",
		[ENPC_MZIMZIZI] = "processEvent030_4",
		[ENPC_IOFA] = "processEvent030_5",
		[ENPC_MARTIALLAIS] = "processEvent030_6",
		[ENPC_PFYNHAEMR] = "processEvent030_7",
		[ENPC_SOSOZE] = "processEvent030_8",
		[ENPC_HIHINE] = "processEvent030_9",
		[ENPC_SATHZANT] = "processEvent030_10",
		[ENPC_GAUTZELIN] = "processEvent030_11",
	},
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_BODENOLF, QFLAG_TALK);
		return;
	end
	if (TALKS[sequence] ~= nil) then
		for classId, _ in pairs(TALKS[sequence]) do
			quest:SetENpc(classId);
		end
	end
	if (sequence == SEQ_000 or sequence == SEQ_005) then
		quest:SetENpc(ENPC_MIMIDOA, QFLAG_TALK);
	elseif (sequence == SEQ_030) then
		quest:SetENpc(ENPC_MIMIDOA, QFLAG_REWARD);
	end
end

local function warpTo(player, spot)
	GetWorldManager():DoZoneChange(player, GUILD_ZONE, nil, 0, 15, spot[1], spot[2], spot[3], spot[4]);
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_BODENOLF) then
		-- More siren work (1 = accepted). It ends on an after-warp fade.
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventBodenolfStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
			player:EndEvent();
			warpTo(player, MIMIDOA_SPOT);
			return;
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and npcClassId == ENPC_MIMIDOA) then
		-- The Barracudas' purge, and the rubber for the earplugs.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent005");
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(ITEM_RUBBER, 1, 1);
		quest:StartSequence(SEQ_005);
	elseif (seq == SEQ_005 and npcClassId == ENPC_MIMIDOA) then
		if (player:GetItemPackage(INVENTORY_NORMAL):HasItem(ITEM_EARPLUG_MOLD, 1)) then
			-- bsm30610 (out to Hope's Bourn), bsm30620 (the sirens) and
			-- bsm30630 (awake at the forge). Ends on an after-warp fade.
			player:GetItemPackage(INVENTORY_NORMAL):RemoveItem(ITEM_EARPLUG_MOLD, 1);
			player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(ITEM_RUBBER, 1);
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
			callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
			quest:StartSequence(SEQ_030);
			player:EndEvent();
			warpTo(player, MIMIDOA_SPOT);
			return;
		end
		callClientFunction(player, "delegateEvent", player, quest, "processEvent005_6");
	elseif (seq == SEQ_030 and npcClassId == ENPC_MIMIDOA) then
		-- bsm30640: the gramophone, the two "sirens", and payment. It ends
		-- on an after-warp fade.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent040");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 2);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddGil(REWARD_GIL);
		player:CompleteQuest(quest);
		player:EndEvent();
		warpTo(player, MIMIDOA_SPOT);
		return;
	elseif (TALKS[seq] ~= nil and TALKS[seq][npcClassId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, TALKS[seq][npcClassId]);
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc, eventName)
	player:EndEvent();
end

function getJournalMapMarkerList(player, quest)
	return {};
end
