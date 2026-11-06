require ("global")
require ("quest")

--[[

Quest Script

Name: 	Playing with Fire
Code: 	Etc1g1
Id: 	110655
Prereq: Level 15, any class

Maroile of Stillglade Fane has sealed a raging fire elemental in a heated
gallipot (key item 11000141). Carry it to three extinguished hearths in
the Central Shroud and let it light them; the work calms it. Then return
to Maroile. Reward a Rope Belt and 500 experience.

Maroile had no spawn or class script; she stands at Stillglade Fane
beside Biddy. The hearths are map objects: the three lone bonfires
(f0takibi1) in the Central Shroud layout, away from Camp Bentbranch's own
fires, at (-193,-628), (-448,-460) and (541,-196). Each gets a "???"
beside it, using free classes 1080070-1080072. They stand in the open
world, so others see them too; a lit one hides for you.

Client script etc1g1: processEventMaroileStart (offer), processEvent000
(Maroile while you go), processEvent010 (the reward). processBUSH plays a
background flame on the hearth; it isn't called, since the hearths here
are stand-ins. Journal steps 215-216.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Light three extinguished hearths.
SEQ_010	= 10;	-- Return to Maroile at Stillglade Fane.

-- Actor Class Ids
ENPC_MAROILE		= 1000512;
ENPC_HEARTHS		= { 1080070, 1080071, 1080072 };

-- Key Items
ITEM_GALLIPOT		= 11000141;

-- Quest Markers
MRKR_HEARTHS		= { 11065501, 11065502, 11065503 };
MRKR_MAROILE		= 11065504;

-- Rewards
REWARD_EXP			= 500;
REWARD_BELT			= 8090402;	-- Rope Belt (the client's reward table, data/01/03/05/61.DAT)

function onStart(player, quest)
	player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(ITEM_GALLIPOT, 1, 1);
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function hearthIndex(classId)
	for i, id in ipairs(ENPC_HEARTHS) do
		if (id == classId) then
			return i;
		end
	end
	return nil;
end

function hearthsLit(data)
	local n = 0;
	for i = 1, #ENPC_HEARTHS do
		if (data:GetFlag(i - 1)) then
			n = n + 1;
		end
	end
	return n;
end

function onStateChange(player, quest, sequence)
	local data = quest:GetData();
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_MAROILE, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ENPC_MAROILE);
		for i, classId in ipairs(ENPC_HEARTHS) do
			-- Lit ones stay registered (no icon) so a touch after
			-- re-entry hides them again.
			quest:SetENpc(classId, data:GetFlag(i - 1) and QFLAG_NONE or QFLAG_TALK);
		end
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_MAROILE, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc)
	local seq = quest:getSequence();
	local classId = npc:GetActorClassId();
	local data = quest:GetData();

	if (seq == SEQ_ACCEPT and classId == ENPC_MAROILE) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventMaroileStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	end

	local hearth = hearthIndex(classId);
	if (seq == SEQ_000 and hearth ~= nil) then
		player:HideActor(npc.Id);
		if (data:GetFlag(hearth - 1)) then
			player:SendMessage(0x20, "", "The power of the fire elemental has already been released here.");
			player:EndEvent();
			return;
		end
		data:SetFlag(hearth - 1);
		local lit = hearthsLit(data);
		player:SendMessage(0x20, "", string.format("The elemental sets the hearth ablaze. (%d/%d)", lit, #ENPC_HEARTHS));
		player:EndEvent();
		if (lit >= #ENPC_HEARTHS) then
			attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
			quest:StartSequence(SEQ_010);
		else
			quest:UpdateENPCs();
		end
		return;
	elseif (seq == SEQ_000 and classId == ENPC_MAROILE) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000");
	elseif (seq == SEQ_010 and classId == ENPC_MAROILE) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1);
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(ITEM_GALLIPOT, 1);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:GetItemPackage(INVENTORY_NORMAL):AddItem(REWARD_BELT, 1, 1);
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
		for i, m in ipairs(MRKR_HEARTHS) do
			if (not data:GetFlag(i - 1)) then
				table.insert(markers, m);
			end
		end
	elseif (seq == SEQ_010) then
		table.insert(markers, MRKR_MAROILE);
	end
	return unpack(markers);
end
