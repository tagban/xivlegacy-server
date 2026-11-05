require ("global")
require ("quest")

--[[

Quest Script

Name: 	Proceed with Caution
Code: 	Etc1g0
Id: 	110654
Prereq: Level 10, any class

Sandre, a botanist at Greatloam Growery, is tired of bumping into the
Watchers in the dark. He gives you a flask of ceruleum compound (key item
11000140) to feed the flames of three Watchers on the road from Gridania
to Camp Bentbranch. Then return to him. Reward Dated Dodoskin Shoes and
300 experience (ZAM).

The Watchers are map objects (the client's t0lmp4 lamps), so each one
gets a "???" beside it, using free classes 1080067-1080069. They stand
in the open world, so others see them too; a fueled one hides for you.
ZAM places them at Black Shroud map (34,32), (31,30) and (29,28); the
lamps there are at (390,-532), (55,-709) and (-195,-978).

Client script etc1g0: processEventSandreStart (offer), processEvent000
(Sandre while you go), processEvent010 (the reward). Journal steps 213-214.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Feed the flames of the three Watchers.
SEQ_010	= 10;	-- Return to Sandre at Greatloam Growery.

-- Actor Class Ids
ENPC_SANDRE			= 1001102;
ENPC_WATCHERS		= { 1080067, 1080068, 1080069 };

-- Key Items
ITEM_CERULEUM		= 11000140;

-- Quest Markers
MRKR_WATCHERS		= { 11065401, 11065402, 11065403 };
MRKR_SANDRE			= 11065404;

-- Rewards
REWARD_EXP			= 300;
REWARD_SHOES		= 8080606;

function onStart(player, quest)
	player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(ITEM_CERULEUM, 1, 1);
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function watcherIndex(classId)
	for i, id in ipairs(ENPC_WATCHERS) do
		if (id == classId) then
			return i;
		end
	end
	return nil;
end

function watchersFueled(data)
	local n = 0;
	for i = 1, #ENPC_WATCHERS do
		if (data:GetFlag(i - 1)) then
			n = n + 1;
		end
	end
	return n;
end

function onStateChange(player, quest, sequence)
	local data = quest:GetData();
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_SANDRE, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ENPC_SANDRE);
		for i, classId in ipairs(ENPC_WATCHERS) do
			-- Fueled ones stay registered (no icon) so a touch after
			-- re-entry hides them again.
			quest:SetENpc(classId, data:GetFlag(i - 1) and QFLAG_NONE or QFLAG_TALK);
		end
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_SANDRE, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc)
	local seq = quest:getSequence();
	local classId = npc:GetActorClassId();
	local data = quest:GetData();

	if (seq == SEQ_ACCEPT and classId == ENPC_SANDRE) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventSandreStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	end

	local watcher = watcherIndex(classId);
	if (seq == SEQ_000 and watcher ~= nil) then
		player:HideActor(npc.Id);
		if (data:GetFlag(watcher - 1)) then
			player:SendMessage(0x20, "", "This Watcher's flames have already been fueled with ceruleum.");
			player:EndEvent();
			return;
		end
		data:SetFlag(watcher - 1);
		local fueled = watchersFueled(data);
		player:SendMessage(0x20, "", string.format("You pour ceruleum over the Watcher's flames. (%d/%d)", fueled, #ENPC_WATCHERS));
		player:EndEvent();
		if (fueled >= #ENPC_WATCHERS) then
			player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(ITEM_CERULEUM, 1);
			attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
			quest:StartSequence(SEQ_010);
		else
			quest:UpdateENPCs();
		end
		return;
	elseif (seq == SEQ_000 and classId == ENPC_SANDRE) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000");
	elseif (seq == SEQ_010 and classId == ENPC_SANDRE) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:GetItemPackage(INVENTORY_NORMAL):AddItem(REWARD_SHOES, 1, 1);
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
	local data = quest:GetData();
	local markers = {};
	if (seq == SEQ_000) then
		for i, m in ipairs(MRKR_WATCHERS) do
			if (not data:GetFlag(i - 1)) then
				table.insert(markers, m);
			end
		end
	elseif (seq == SEQ_010) then
		table.insert(markers, MRKR_SANDRE);
	end
	return unpack(markers);
end
