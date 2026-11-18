require ("global")
require ("quest")
require ("jobquest")

--[[

Quest Script

Name:	Five Easy Pieces
Code:	Mnk0j5
Id:		111225
Prereq: Mnk0j4, Monk 45

Widargelt wants to know what you told Erik about him, then tells you of
the monk's garb, which channels the chakras' power. He has hidden four
pieces of it on old battlegrounds as a trial (processEvent_WIDARGELT_Start):
Dzemael Darkhold in the Coerthas central highlands, the U'Ghamaro Mines in
Upper La Noscea, Turning Leaf in the West Shroud and a cliff over the
Sagolii southeast of Ul'dah. Each hiding place gives up its piece
(processEvent_getAF_info); with the fourth the quest is done.

The client has no markers or positions for the hiding places; they stand
near the place's aetheryte camp or a known spot nearby, and the piece found
at each is a guess. Widargelt keeps the cyclas (Mnk0j6 ends with it).

]]

local SEQ_000 = 0;	-- Find the four hidden pieces of the monk's garb.

local ENPC_ERIK			= 1060033;
local ENPC_WIDARGELT	= 1060032;

-- Hiding place (push circle) -> the piece found there and its quest flag.
local PIECES = {
	[1090915] = { item = 8013502, flag = 0 }, -- Dzemael Darkhold: Temple Circlet
	[1090916] = { item = 8071402, flag = 1 }, -- U'Ghamaro Mines: Temple Gloves
	[1090917] = { item = 8051402, flag = 2 }, -- Turning Leaf: Temple Gaskins
	[1090918] = { item = 8081802, flag = 3 }, -- the Sagolii cliff: Temple Boots
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_WIDARGELT, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ENPC_WIDARGELT);
		quest:SetENpc(ENPC_ERIK);
		local data = quest:GetData();
		for classId, piece in pairs(PIECES) do
			if (not data:GetFlag(piece.flag)) then
				quest:SetENpc(classId, QFLAG_PUSH, false, true);
			end
		end
	end
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	if (quest:GetSequence() == SEQ_ACCEPT) then
		if (npcClassId == ENPC_WIDARGELT) then
			-- The garb and its hiding places (1 = accepted).
			if (callClientFunction(player, "delegateEvent", player, quest, "processEvent_WIDARGELT_Start") == 1) then
				player:AcceptQuest(quest);
			end
		end
	elseif (npcClassId == ENPC_WIDARGELT) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_WIDARGELT_Follow");
	elseif (npcClassId == ENPC_ERIK) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_ERIK_Follow");
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
