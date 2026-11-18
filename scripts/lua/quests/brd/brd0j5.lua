require ("global")
require ("quest")
require ("jobquest")

--[[

Quest Script

Name:	Pieces of the Past
Code:	Brd0j5
Id:		111305
Prereq: Brd0j4, Bard 45

Jehantel tells how the moogle Pukno Poki gave him the choral attire, and
how in his despair after Griffin Crossing he scattered it across the realm.
He marks where each piece lies and asks you to claim them
(processEvent_JEHANTEL_Start): Cutter's Cry in Northern Thanalan, Zahar'ak
in Southern Thanalan, near Turning Leaf in the West Shroud and a cave south
of Iron Lake. Each place gives up its piece (processEvent_getAF_info); with
the fourth the quest is done.

The client has no markers or positions for the four places; the piece
found at each is a guess. The shirt comes in Brd0j6.

]]

local SEQ_000 = 0;	-- Find the four pieces of the choral attire.

local ENPC_JEHANTEL = 1060039;

-- Resting place (push circle) -> the piece found there and its quest flag.
local PIECES = {
	[1090951] = { item = 8013505, flag = 0 }, -- Cutter's Cry: Choral Chapeau
	[1090952] = { item = 8071405, flag = 1 }, -- Zahar'ak: Choral Ringbands
	[1090953] = { item = 8051405, flag = 2 }, -- near Turning Leaf: Choral Tights
	[1090954] = { item = 8081805, flag = 3 }, -- south of Iron Lake: Choral Sandals
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_JEHANTEL, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ENPC_JEHANTEL);
		local data = quest:GetData();
		for classId, piece in pairs(PIECES) do
			if (not data:GetFlag(piece.flag)) then
				quest:SetENpc(classId, QFLAG_PUSH, false, true);
			end
		end
	end
end

function onTalk(player, quest, npc, eventName)
	if (npc.GetActorClassId() == ENPC_JEHANTEL) then
		if (quest:GetSequence() == SEQ_ACCEPT) then
			-- The choral attire (1 = accepted).
			if (callClientFunction(player, "delegateEvent", player, quest, "processEvent_JEHANTEL_Start") == 1) then
				player:AcceptQuest(quest);
			end
		else
			-- The markings on your map.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_JEHANTEL_Follow");
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
