require ("global")
require ("quest")

--[[

Quest Script

Name: 	Seashells by the Seashore
Code: 	Etc1l9
Id: 	110642
Prereq: Level 20, any class

Little Fupepe of Aleport may not leave the hamlet, so she asks you to
bring her four conch shells from the beach below Camp Bloodshore (ZAM: map
(37,22)). Click each of the four "???" on the sand; each one is a shell
(key item 11000174, the conch shells). Fupepe trades her best treasure for
them. Reward a Cotton Coif (the client's reward table, data/01/03/05/61.DAT;
ZAM's 12 boiled crayfish are older).

The shells use free "???" classes 1080063-1080066. They stand in the open
world, so others see them too; a picked shell hides for you.

Client script etc1l9: processEventStart (offer), processEventFree (while
you look), processEventClear (the reward), shell ("You find nothing out
of the ordinary", for a shell already taken). Journal steps 184-186.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Find four conch shells on the beach below Camp Bloodshore.
SEQ_010	= 10;	-- Bring the shells to Fupepe in Aleport.

-- Actor Class Ids
ENPC_FUPEPE			= 1001301;
ENPC_SHELLS			= { 1080063, 1080064, 1080065, 1080066 };

-- Key Items
ITEM_CONCH_SHELLS	= 11000174;

-- Quest Markers
MRKR_BEACH			= 11064201;
MRKR_FUPEPE			= 11064202;

-- Rewards
REWARD_COIF			= 8010523;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function shellIndex(classId)
	for i, id in ipairs(ENPC_SHELLS) do
		if (id == classId) then
			return i;
		end
	end
	return nil;
end

function shellsFound(data)
	local n = 0;
	for i = 1, #ENPC_SHELLS do
		if (data:GetFlag(i - 1)) then
			n = n + 1;
		end
	end
	return n;
end

function onStateChange(player, quest, sequence)
	local data = quest:GetData();
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_FUPEPE, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ENPC_FUPEPE);
		for i, classId in ipairs(ENPC_SHELLS) do
			-- Found ones stay registered (no icon) so a touch after
			-- re-entry hides them again.
			quest:SetENpc(classId, data:GetFlag(i - 1) and QFLAG_NONE or QFLAG_TALK);
		end
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_FUPEPE, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc)
	local seq = quest:getSequence();
	local classId = npc:GetActorClassId();
	local data = quest:GetData();

	if (seq == SEQ_ACCEPT and classId == ENPC_FUPEPE) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	end

	local shell = shellIndex(classId);
	if (seq == SEQ_000 and shell ~= nil) then
		if (data:GetFlag(shell - 1)) then
			callClientFunction(player, "delegateEvent", player, quest, "shell");
			player:HideActor(npc.Id);
			player:EndEvent();
			return;
		end
		data:SetFlag(shell - 1);
		player:HideActor(npc.Id);
		local found = shellsFound(data);
		if (found == 1) then
			player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(ITEM_CONCH_SHELLS, 1, 1);
			player:SendGameMessage(GetWorldMaster(), 25246, MESSAGE_TYPE_SYSTEM, ITEM_CONCH_SHELLS, 1); -- You obtain <item>.
		end
		player:SendMessage(0x20, "", string.format("You find a conch shell. (%d/%d)", found, #ENPC_SHELLS));
		player:EndEvent();
		if (found >= #ENPC_SHELLS) then
			attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
			quest:StartSequence(SEQ_010);
		else
			quest:UpdateENPCs();
		end
		return;
	elseif (seq == SEQ_000 and classId == ENPC_FUPEPE) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventFree");
	elseif (seq == SEQ_010 and classId == ENPC_FUPEPE) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventClear");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 0, 1, 1);
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(ITEM_CONCH_SHELLS, 1);
		player:GetItemPackage(INVENTORY_NORMAL):AddItem(REWARD_COIF, 1, 1);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_000) then
		return MRKR_BEACH;
	elseif (seq == SEQ_010) then
		return MRKR_FUPEPE;
	end
end
