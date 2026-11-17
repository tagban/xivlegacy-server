require ("global")
require ("quest")
require ("dungeon")

--[[

Quest Script

Name: 	A Feast of Fools
Code: 	Sum6m0
Id: 	110816
Prereq: Level 45, any nation's It Kills with Fire (Gc?101; ANY_OF_PREREQUISITES
		in quest_offers.rs).

Louisoix, at Apkallus Falls, tells of moogles vanishing into an ensorcelled
ward deep in the Twelveswood. Five enchanted keystones open it, each kept
by a guardian beast near Turning Leaf in the West Shroud: Queen Gougou,
Buata, Capricious Cassie, Spiteful and Great Oak. Bring all five to the
moogle Pukwa Pika south of Turning Leaf, step through the ward into
Thornmarch, and put down Good King Moggle Mog XII and his corrupted court.
Pukwa sends you back to Louisoix, who hears of it. Experience only.

Client text sheet 7488. The battle is the client's raid list entry 5,
"Thornmarch", run by its InstanceRaidDarkMoogle director. Thornmarch is
zone 238 on the West Shroud map; the arena is the layout's moogle ring
(isgrp_mog_ring, about -2368, -896).

Our choices, where the client gives no number: the guardians' places
around Turning Leaf and their strength, the court's numbers (seven
moogles of 3,000-4,000 HP and the king at 36,000, all fought at once, no
moves yet). The client's second-visit route (unmarked keystones, two per
key, from Pukwa) and the repeat fight are not built: the quest runs once.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Take the five keystones and bring them to Pukwa Pika.
SEQ_010	= 10;	-- Step through the ward and defeat Good King Moggle Mog XII.
SEQ_020	= 20;	-- Tell Pukwa Pika (set by the battle's director).
SEQ_030	= 30;	-- Report to Louisoix.

-- Quest Actors
LOUISOIX				= 1060022;
PUKWA_PIKA				= 1001836;	-- south of Turning Leaf, West Shroud

-- The five guardians (battle npc class -> the keystone each keeps)
GUARDIANS = {
	[2100519] = 11000211,	-- Queen Gougou
	[2101515] = 11000212,	-- Buata
	[2101011] = 11000213,	-- Capricious Cassie
	[2106221] = 11000214,	-- Spiteful
	[2102806] = 11000215,	-- Great Oak
};

ENTRY_LEVEL				= 45;
RAID_CONTENT			= 5;		-- Thornmarch in the client's raid list
TIME_LIMIT				= 30;		-- minutes, as Pukwa tells it

-- Reward (the client's reward sheet row: EXP tier 6 in slot 1, nothing else)
REWARD_EXP				= 1322;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

local function hasAllKeystones(player)
	local keys = player:GetItemPackage(INVENTORY_KEYITEMS);
	for _, item in pairs(GUARDIANS) do
		if not keys:HasItem(item) then
			return false;
		end
	end
	return true;
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(LOUISOIX, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(LOUISOIX);
		quest:SetENpc(PUKWA_PIKA, hasAllKeystones(player) and QFLAG_TALK or QFLAG_NONE);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(PUKWA_PIKA, QFLAG_TALK);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(PUKWA_PIKA, QFLAG_TALK);
		quest:SetENpc(LOUISOIX);
	elseif (sequence == SEQ_030) then
		quest:SetENpc(PUKWA_PIKA);
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
		-- the vanishing moogles, the ward and its five keystones
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventLOUISOIXStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (sequence == SEQ_000 and classId == LOUISOIX) then
		-- the guardians' names once more
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000");
	elseif (sequence == SEQ_000 and classId == PUKWA_PIKA) then
		if hasAllKeystones(player) then
			-- Pukwa takes the keystones and opens the ward
			callClientFunction(player, "delegateEvent", player, quest, "processEvent015", TIME_LIMIT);
			local keys = player:GetItemPackage(INVENTORY_KEYITEMS);
			for _, item in pairs(GUARDIANS) do
				keys:RemoveItem(item, 1);
			end
			quest:StartSequence(SEQ_010);
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent015_2");
		end
	elseif (sequence == SEQ_010 and classId == PUKWA_PIKA) then
		-- "Are you ready to step through the ward?"
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		if (callClientFunction(player, "askEnterInstanceRaid", RAID_CONTENT) and mayEnter(player)) then
			player:EndEvent();
			enterDungeon(player, "thornmarch");
			return;
		end
	elseif (sequence == SEQ_020 and classId == PUKWA_PIKA) then
		-- the moogles summoned their king; run and tell Louisoix
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
		quest:StartSequence(SEQ_030);
	elseif (sequence == SEQ_030 and classId == PUKWA_PIKA) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030_2");
	elseif (sequence == SEQ_030 and classId == LOUISOIX) then
		-- the moogle king put down
		callClientFunction(player, "delegateEvent", player, quest, "processEvent035");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

-- Each guardian leaves its keystone.
function onKillBNpc(player, quest, bnpc)
	local item = GUARDIANS[bnpc];
	if (quest:GetSequence() ~= SEQ_000 or item == nil) then
		return;
	end
	local keys = player:GetItemPackage(INVENTORY_KEYITEMS);
	if not keys:HasItem(item) then
		keys:AddItem(item, 1, 1);
	end
	quest:UpdateENPCs();
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
