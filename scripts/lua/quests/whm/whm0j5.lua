require ("global")
require ("quest")
require ("jobquest")

--[[

Quest Script

Name:	In Search of Succor
Code:	Whm0j5
Id:		111245
Prereq: Whm0j4, White Mage 45

To calm the elementals, Raya-O-Senna wants the garb of succor worn by the
white mages of old, and marks four pieces on your map
(processEvent_RAYA_offer): Dzemael Darkhold in the Coerthas central
highlands, Zahar'ak in Southern Thanalan, Turning Leaf in the West Shroud
and Tiger Helm Island in Eastern La Noscea. Each place gives up its piece
(processEvent_getAF_info); with all four, go back to Raya-O
(processEvent_RAYA_O_clear).

The client has no markers or positions for the four places; they stand
near each place's aetheryte, and the piece found at each is a guess. The
fifth piece, the robe, comes in Whm0j6.

]]

local SEQ_000 = 0;	-- Find the four pieces of the garb of succor.
local SEQ_010 = 10;	-- Return to Raya-O-Senna.

local ENPC_RAYA_O_SENNA = 1001570;

-- Resting place (push circle) -> the piece found there and its quest flag.
local PIECES = {
	[1090924] = { item = 8013506, flag = 0 }, -- Dzemael Darkhold: Healer's Circlet
	[1090925] = { item = 8071406, flag = 1 }, -- Zahar'ak: Healer's Gloves
	[1090926] = { item = 8051406, flag = 2 }, -- Turning Leaf: Healer's Culottes
	[1090927] = { item = 8081806, flag = 3 }, -- Tiger Helm Island: Healer's Boots
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_RAYA_O_SENNA, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ENPC_RAYA_O_SENNA);
		local data = quest:GetData();
		for classId, piece in pairs(PIECES) do
			if (not data:GetFlag(piece.flag)) then
				quest:SetENpc(classId, QFLAG_PUSH, false, true);
			end
		end
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_RAYA_O_SENNA, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc, eventName)
	local seq = quest:GetSequence();
	if (npc.GetActorClassId() == ENPC_RAYA_O_SENNA) then
		if (seq == SEQ_ACCEPT) then
			-- The garb of succor (1 = accepted).
			if (callClientFunction(player, "delegateEvent", player, quest, "processEvent_RAYA_offer") == 1) then
				player:AcceptQuest(quest);
			end
		elseif (seq == SEQ_000) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_RAYA_O_follow");
		elseif (seq == SEQ_010) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_RAYA_O_clear");
			player:CompleteQuest(quest);
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
			quest:StartSequence(SEQ_010);
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
