require ("global")
require ("quest")
require ("jobquest")

--[[

Quest Script

Name:	Poisoned Hearts
Code:	Pld0j4
Id:		111284
Prereq: Pld0j3, Paladin 45

Old records tie Solkzagyl to the Monetarists, a faction of the Syndicate.
While Jenlyns hunts the traitor, he asks you to recover the four pieces of
the gallant armor (processEvent_JENLYNS_Start): the Aurum Vale west of Camp
Ever Lakes, Natalan east of Camp Dragonhead, a cave north of Camp
Brittlebark in Mor Dhona and a cave northeast of Camp Crimson Bark in the
West Shroud. Each place gives up its piece (processEvent_getAF_info); with
the fourth the quest is done.

The client has no markers or positions for the four places; they stand
near each place's camp, and the piece found at each is a guess. The
surcoat comes in Pld0j6.

]]

local SEQ_000 = 0;	-- Find the four pieces of the gallant armor.

local ENPC_JENLYNS = 1060042;

-- Resting place (push circle) -> the piece found there and its quest flag.
local PIECES = {
	[1090941] = { item = 8013501, flag = 0 }, -- the Aurum Vale: Gallant Coronet
	[1090942] = { item = 8071401, flag = 1 }, -- Natalan: Gallant Gauntlets
	[1090943] = { item = 8051401, flag = 2 }, -- north of Camp Brittlebark: Gallant Cuisses
	[1090944] = { item = 8081801, flag = 3 }, -- northeast of Camp Crimson Bark: Gallant Sollerets
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_JENLYNS, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ENPC_JENLYNS);
		local data = quest:GetData();
		for classId, piece in pairs(PIECES) do
			if (not data:GetFlag(piece.flag)) then
				quest:SetENpc(classId, QFLAG_PUSH, false, true);
			end
		end
	end
end

function onTalk(player, quest, npc, eventName)
	if (npc.GetActorClassId() == ENPC_JENLYNS) then
		if (quest:GetSequence() == SEQ_ACCEPT) then
			-- The gallant armor (1 = accepted).
			if (callClientFunction(player, "delegateEvent", player, quest, "processEvent_JENLYNS_Start") == 1) then
				player:AcceptQuest(quest);
			end
		else
			-- Jenlyns hunts the traitor.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_JENLYNS_Follow");
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
