require ("global")
require ("quest")
require ("jobquest")

--[[

Quest Script

Name:	Looking the Part
Code:	War0j4
Id:		111204
Prereq: War0j3, Warrior 45

Curious Gorge has found where his ancestors' five pieces of armor were
laid to rest, each at the site of a great battle. He marks four on your
map and goes after the fifth himself (processEventCURIOUS_GORGE_Start):
Cutter's Cry in Northern Thanalan, Natalan in the Coerthas central
highlands, Turning Leaf in the West Shroud and Craneperch Tower in Lower
La Noscea. Each resting place gives up its piece (processEvent_getAF_info);
with the fourth the quest is done.

The client has no markers or positions for the resting places; they stand
near each place's aetheryte camp (Cutters Pass, Feathergorge, Turning
Leaf, Widow Cliffs), and the piece found at each is a guess. Gorge keeps
the cuirass (War0j5 starts with him wearing it).

]]

local SEQ_000 = 0;	-- Find the four pieces of armor.

local ENPC_CURIOUS_GORGE = 1060028;

-- Resting place (push circle) -> the piece found there and its quest flag.
local PIECES = {
	[1090904] = { item = 8013503, flag = 0 }, -- Cutter's Cry: Fighter's Burgeonet
	[1090905] = { item = 8071403, flag = 1 }, -- Natalan: Fighter's Gauntlets
	[1090906] = { item = 8051403, flag = 2 }, -- Turning Leaf: Fighter's Breeches
	[1090907] = { item = 8081803, flag = 3 }, -- Craneperch Tower: Fighter's Jackboots
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_CURIOUS_GORGE, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ENPC_CURIOUS_GORGE);
		local data = quest:GetData();
		for classId, piece in pairs(PIECES) do
			if (not data:GetFlag(piece.flag)) then
				quest:SetENpc(classId, QFLAG_PUSH, false, true);
			end
		end
	end
end

function onTalk(player, quest, npc, eventName)
	if (npc.GetActorClassId() == ENPC_CURIOUS_GORGE) then
		if (quest:GetSequence() == SEQ_ACCEPT) then
			-- The armor's resting places (1 = accepted).
			if (callClientFunction(player, "delegateEvent", player, quest, "processEventCURIOUS_GORGE_Start") == 1) then
				player:AcceptQuest(quest);
			end
		else
			-- Wear them only if your will can bear them.
			callClientFunction(player, "delegateEvent", player, quest, "processEventCURIOUS_GORGE_Follow");
		end
	end
	player:EndEvent();
end

function onPush(player, quest, npc)
	local piece = PIECES[npc:GetActorClassId()];
	local data = quest:GetData();
	if (quest:GetSequence() == SEQ_000 and piece ~= nil and not data:GetFlag(piece.flag)) then
		data:SetFlag(piece.flag);
		player:GetItemPackage(INVENTORY_NORMAL):AddItem(piece.item, 1, 1);
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_getAF_info");
		local found = 0;
		for _, p in pairs(PIECES) do
			if (data:GetFlag(p.flag)) then found = found + 1; end
		end
		if (found == 4) then
			player:CompleteQuest(quest);
		else
			quest:UpdateENPCs();
		end
	end
	player:EndEvent();
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
