require ("global")
require ("quest")
require ("dungeon")

--[[

Quest Script

Name: 	Taming the Tempest
Code: 	Sum6g0
Id: 	110867
Prereq: Level 45, any nation's In for Garuda Wakening (Gc?104;
		ANY_OF_PREREQUISITES in quest_offers.rs).

Louisoix, at Apkallus Falls, would have you face Garuda again: she has
gathered her strength once more. The Ixal now guard the aetheryte that
first took you to her, but another, in a cave north-east of Natalan in the
Coerthas Central Highlands, is less watched. It answers only something
like the Vortex Fletchings you once had, so bring Louisoix five Vortex
Headdresses from the Ixal about Natalan and he makes them. Garuda falls in
the Howling Eye (Hard), and Louisoix hears of it. Experience only.

Client text sheet 10224. The battle is the client's raid list entry 11,
"the Howling Eye (Hard)", run by its InstanceRaidNormalGaruda director (the
GC fight is InstanceRaidLesserGaruda, entry 12). The beastman aetheryte is
a push circle in the cave north-east of Natalan (zone 143, tools/terrain
floor ~297 under the ridge).

Our choices, where the client gives no number: headdresses drop from one
Natalan Ixal kill in two (the client says "Ixal and beasts"; only the Ixal
we spawn there count), and the fight's numbers (Garuda level 52, 40,000
HP, the GC Garuda's moves). No party size check, no re-entry timer.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Bring Louisoix five Vortex Headdresses.
SEQ_010	= 10;	-- Use the beastman aetheryte and defeat Garuda.
SEQ_020	= 20;	-- Report to Louisoix (set by the battle's director).

-- Quest Actors
LOUISOIX				= 1060022;
BEASTMAN_AETHERYTE		= 1091201;	-- the cave north-east of Natalan

-- Natalan's Ixal (battle npc classes)
NATALAN_IXAL = {
	[2106447] = true,	-- Natalan pikecarver
	[2106453] = true,	-- Natalan logsplitter
	[2106460] = true,	-- Natalan wolftamer
	[2106467] = true,	-- Natalan boneknitter
};

-- Items
VORTEX_FLETCHINGS		= 11000352;	-- key item
VORTEX_HEADDRESS		= 10011155;
HEADDRESSES_NEEDED		= 5;
HEADDRESS_CHANCE		= 2;		-- one kill in this many leaves a headdress

ENTRY_LEVEL				= 45;
RAID_CONTENT			= 11;		-- the Howling Eye (Hard) in the client's raid list

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

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();

	if (sequence == SEQ_ACCEPT and classId == LOUISOIX) then
		-- Garuda risen again, and the headdresses Louisoix needs
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (sequence == SEQ_000 and classId == LOUISOIX) then
		local bag = player:GetItemPackage(INVENTORY_NORMAL);
		if (bag:HasItem(VORTEX_HEADDRESS, HEADDRESSES_NEEDED)) then
			-- "Have Louisoix create Vortex Fletchings?" (1 = yes), then the
			-- way to the cave north-east of Natalan
			local made = callClientFunction(player, "delegateEvent", player, quest, "processEvent000");
			if (made == 1) then
				bag:RemoveItem(VORTEX_HEADDRESS, HEADDRESSES_NEEDED);
				player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(VORTEX_FLETCHINGS, 1, 1);
				quest:StartSequence(SEQ_010);
			end
		elseif (bag:HasItem(VORTEX_HEADDRESS, 1)) then
			-- the same ask; a yes is told the feathers are too few
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000_2");
		else
			-- where the headdresses are found
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000_3");
		end
	elseif (sequence == SEQ_010 and classId == LOUISOIX) then
		-- the way to the beastman aetheryte
		callClientFunction(player, "delegateEvent", player, quest, "processEvent005_LOUISOIX");
	elseif (sequence == SEQ_020 and classId == LOUISOIX) then
		-- the wind primal put down
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

-- Natalan's Ixal now and then leave a Vortex Headdress.
function onKillBNpc(player, quest, bnpc)
	if (quest:GetSequence() == SEQ_000 and NATALAN_IXAL[bnpc]
		and math.random(HEADDRESS_CHANCE) == 1) then
		player:GetItemPackage(INVENTORY_NORMAL):AddItem(VORTEX_HEADDRESS, 1, 1);
	end
end

function onPush(player, quest, npc)
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();

	if (classId == BEASTMAN_AETHERYTE and sequence == SEQ_010) then
		-- the beastman aetheryte (the client's own entry prompt)
		if (callClientFunction(player, "askEnterInstanceRaid", RAID_CONTENT) and mayEnter(player)) then
			player:EndEvent();
			enterDungeon(player, "howling_hard");
			return;
		end
	end
	player:EndEvent();
	quest:UpdateENPCs();
end

function getJournalInformation(player, quest)
	return HEADDRESSES_NEEDED, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
