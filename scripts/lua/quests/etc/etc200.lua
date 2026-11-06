require ("global")
require ("quest")
require ("dungeon")

--[[

Quest Script

Name: 	A Light in the Dark
Code: 	Etc200
Id: 	110818
Prereq: Level 45, any class

Sibold the Stoic, last of the Darklight Raiders, has gone back each summer
to the lair in Cutter's Cry where the chimera tore his companions apart.
His bones can no longer make the trek, so he asks you to carry his bouquet
(key item 11000222) into Cutter's Cry and lay it on their resting place.
Back in Ul'dah he tells you how he hid while his brothers died. The reward
is experience only (the client's reward table, data/01/03/05/61.DAT, gives
it as a rank, so the amount is an estimate).

Cutter's Cry is the server's dungeon copy (dungeon.lua). Retail let you in
through the Immortal Flames at the cave mouth; the client script has no
event for that, so a spot by Cutter's Pass (where the dungeon's exit sets
you down) takes quest holders who are Disciples of War or Magic at the
quest's level inside. The resting place is a spot in the last chamber,
past the sand basilisks (SimpleContentDungeonCuttersCry spawns it in every
copy; its place is an estimate, the chimera isn't placed yet). Laying the
flowers takes you back out to Cutter's Pass.

Client script etc200: processEventSIBOLDStart (offer), processEvent000
(Sibold while you go), processEvent005 (laying the bouquet),
processEvent010 (Sibold's story). Journal steps 466-468.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Lay the bouquet in Cutter's Cry.
SEQ_005	= 5;	-- Tell Sibold in Ul'dah.

-- Actor Class Ids
ENPC_SIBOLD			= 1001932;
ENTRY_TRIGGER		= 1090615;
TOMB_TRIGGER		= 1090616;

-- Key Items
ITEM_BOUQUET		= 11000222;

-- Quest Markers
MRKR_CUTTERS_CRY	= 11081801;
MRKR_SIBOLD			= 11081802;

-- Entry to Cutter's Cry, as the client's journal tells it.
ENTRY_LEVEL			= 45;

-- Rewards
REWARD_EXP			= 3500;

function onStart(player, quest)
	player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(ITEM_BOUQUET, 1, 1);
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_SIBOLD, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ENPC_SIBOLD);
		quest:SetENpc(ENTRY_TRIGGER, QFLAG_PUSH, false, true);
		quest:SetENpc(TOMB_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_005) then
		quest:SetENpc(ENPC_SIBOLD, QFLAG_REWARD);
	end
end

local function mayEnter(player)
	return (player:IsDiscipleOfWar() or player:IsDiscipleOfMagic())
		and player:GetHighestLevel() >= ENTRY_LEVEL;
end

function onTalk(player, quest, npc)
	local seq = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (classId == ENPC_SIBOLD) then
		if (seq == SEQ_ACCEPT) then
			local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventSIBOLDStart");
			if (accepted == 1) then
				player:AcceptQuest(quest);
			end
			player:EndEvent();
			return;
		elseif (seq == SEQ_000) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000");
		elseif (seq == SEQ_005) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1);
			player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(ITEM_BOUQUET, 1);
			player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
			player:EndEvent();
			player:CompleteQuest(quest);
			return;
		end
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onPush(player, quest, npc)
	local classId = npc:GetActorClassId();
	if (quest:getSequence() == SEQ_000) then
		if (classId == ENTRY_TRIGGER and mayEnter(player)) then
			player:EndEvent();
			enterDungeon(player, "cutters");
			return;
		elseif (classId == TOMB_TRIGGER) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005");
			attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
			player:EndEvent();
			quest:StartSequence(SEQ_005);
			leaveDungeon(player);
			return;
		end
	end
	player:EndEvent();
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_000) then
		return MRKR_CUTTERS_CRY;
	elseif (seq == SEQ_005) then
		return MRKR_SIBOLD;
	end
end
