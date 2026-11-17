require ("global")
require ("quest")
require ("dungeon")

--[[

Quest Script

Name: 	Ifrit Bleeds, We Can Kill It
Code: 	Sum6a0
Id: 	110627
Prereq: Level 45, any nation's It Kills with Fire (Gc?101; ANY_OF_PREREQUISITES
		in quest_offers.rs).

Louisoix, at Apkallus Falls, would have you face Ifrit again: the crystals'
power spilled into him when last you fought, and he has grown stronger.
The aetherial gate is gone, so the way in is the Amalj'aa's own beastman
aetheryte, in a cave south-west of Camp Broken Water, and it answers only
the Inferno Lamp. Take the lamp from Flamefist Ahlygg Roh, commander of
Zahar'ak in Southern Thanalan, or bring Louisoix Inferno Tapers from the
stronghold's lesser Amalj'aa and he makes one. Ifrit falls in the Bowl of
Embers (Hard), and Louisoix hears of it. Experience only.

Client text sheet 3181 (English rows 0C/74), Gridania journal steps 370-373
(0B/45/08/34). The battle is the client's raid list entry 3, "the Bowl of
Embers (Hard)", run by its InstanceRaidNormalIfrit director (the GC fight
is InstanceRaidLesserIfrit, entry 4). Zahar'ak stands by the zanrak
aetheryte gate (zone 174); the beastman aetheryte is a push circle in the
cave under Camp Broken Water (tools/terrain floor ~250).

Our choices, where the client gives no number: 5 tapers make a lamp (the
journal fills the count from the quest, not from text), tapers drop from
one Zahar'ak kill in two, and the fight's numbers (Ifrit level 52, 36,000
HP, the GC Ifrit's moves; no Infernal Nails phase). No party size check
(the server has no party state for scripts), no re-entry timer.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Obtain the Inferno Lamp.
SEQ_010	= 10;	-- Use the beastman aetheryte and defeat Ifrit.
SEQ_020	= 20;	-- Report to Louisoix (set by the battle's director).

-- Quest Actors
LOUISOIX				= 1060022;
BEASTMAN_AETHERYTE		= 1091200;	-- the cave under Camp Broken Water

-- Zahar'ak (battle npc classes)
FLAMEFIST				= 2162051;	-- Flamefist Ahlygg Roh, who holds the lamp
LESSER_AMALJAA = {
	[2162037] = true,	-- Zahar'ak sniper
	[2162044] = true,	-- Zahar'ak halberdier
	[2162050] = true,	-- Zahar'ak drubber
	[2162059] = true,	-- Zahar'ak ostiary
};

-- Items
INFERNO_LAMP			= 11000351;	-- key item
INFERNO_TAPER			= 10011126;
TAPERS_NEEDED			= 5;
TAPER_CHANCE			= 2;		-- one kill in this many leaves a taper

ENTRY_LEVEL				= 45;
RAID_CONTENT			= 3;		-- the Bowl of Embers (Hard) in the client's raid list

-- Reward (the client's reward sheet row: EXP tier 6 in slot 1, nothing else)
REWARD_EXP				= 1322;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(LOUISOIX, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(LOUISOIX, QFLAG_TALK);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(LOUISOIX);
		quest:SetENpc(BEASTMAN_AETHERYTE, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(LOUISOIX, QFLAG_REWARD);
	end
end

local function mayEnter(player)
	return (player:IsDiscipleOfWar() or player:IsDiscipleOfMagic())
		and player:GetHighestLevel() >= ENTRY_LEVEL;
end

local function giveLamp(player, quest)
	player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(INFERNO_LAMP, 1, 1);
	quest:StartSequence(SEQ_010);
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();

	if (sequence == SEQ_ACCEPT and classId == LOUISOIX) then
		-- the primal grown stronger, and the two ways to the lamp
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventLOUISOIXStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (sequence == SEQ_000 and classId == LOUISOIX) then
		local bag = player:GetItemPackage(INVENTORY_NORMAL);
		if (bag:HasItem(INFERNO_TAPER, TAPERS_NEEDED)) then
			-- "Have Louisoix create the lamp?" (1 = yes)
			local made = callClientFunction(player, "delegateEvent", player, quest, "processEvent_005");
			if (made == 1) then
				bag:RemoveItem(INFERNO_TAPER, TAPERS_NEEDED);
				giveLamp(player, quest);
			end
		else
			-- the same ask; a yes is told the tapers are too few
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_005_2");
		end
	elseif (sequence == SEQ_010 and classId == LOUISOIX) then
		-- bearing the lamp: the way to the aetheryte
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_005_3");
	elseif (sequence == SEQ_020 and classId == LOUISOIX) then
		-- the Lord of the Inferno bested
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

-- Flamefist leaves the lamp; the lesser Amalj'aa, now and then a taper.
function onKillBNpc(player, quest, bnpc)
	if (quest:GetSequence() ~= SEQ_000) then
		return;
	end
	if (bnpc == FLAMEFIST) then
		giveLamp(player, quest);
	elseif (LESSER_AMALJAA[bnpc] and math.random(TAPER_CHANCE) == 1) then
		player:GetItemPackage(INVENTORY_NORMAL):AddItem(INFERNO_TAPER, 1, 1);
	end
end

function onPush(player, quest, npc)
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();

	if (classId == BEASTMAN_AETHERYTE and sequence == SEQ_010) then
		-- the beastman aetheryte (the client's own entry prompt)
		if (callClientFunction(player, "askEnterInstanceRaid", RAID_CONTENT) and mayEnter(player)) then
			player:EndEvent();
			enterDungeon(player, "embers_hard");
			return;
		end
	end
	player:EndEvent();
	quest:UpdateENPCs();
end

function getJournalInformation(player, quest)
	return TAPERS_NEEDED, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
