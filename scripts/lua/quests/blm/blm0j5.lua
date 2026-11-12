require ("global")
require ("quest")
require ("jobquest")

--[[

Quest Script

Name:	Gearing Up
Code:	Blm0j5
Id:		111265
Prereq: Blm0j4, Black Mage 45

The kobold Da Za came from O'Ghomoro after the same legend as Kazagg Chah
and Dozol Meloc. Under the gem's light his ancestor Da Gu's stone tablet
shows that closing the Voidgate needs a certain garb, and names where four
pieces lie (processEvent_DAZA_Start): the Aurum Vale west of Camp Ever
Lakes, Dusk Vigil north of Camp Riversmeet, a cave west of Camp
Brittlebark in Mor Dhona and a cave south of Camp Broken Water. Each place
gives up its piece (processEvent_getAF_info); with the fourth the quest is
done.

The client has no markers or positions for the four places; they stand
near each place's camp, and the piece found at each is a guess. The robe
comes in Blm0j6.

]]

local SEQ_000 = 0;	-- Find the four pieces of the black mage's garb.

local ENPC_LALAI		= 1060034;
local ENPC_KAZAGG_CHAH	= 1060036;
local ENPC_DOZOL_MELOC	= 1060037;
local ENPC_DA_ZA		= 1060038;

-- Resting place (push circle) -> the piece found there and its quest flag.
local PIECES = {
	[1090933] = { item = 8013507, flag = 0 }, -- the Aurum Vale: Wizard's Petasos
	[1090934] = { item = 8071407, flag = 1 }, -- Dusk Vigil: Wizard's Gloves
	[1090935] = { item = 8051407, flag = 2 }, -- west of Camp Brittlebark: Wizard's Tonban
	[1090936] = { item = 8081807, flag = 3 }, -- south of Camp Broken Water: Wizard's Crakows
};

local FOLLOW = {
	[ENPC_DA_ZA] = "processEvent_DAZA_Follow",
	[ENPC_KAZAGG_CHAH] = "processEvent_KAZAGGCHAH_Follow",
	[ENPC_DOZOL_MELOC] = "processEvent_DOZOLMELOC_Follow",
	[ENPC_LALAI] = "processEvent_LALAI_Follow",
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_DA_ZA, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		for classId, _ in pairs(FOLLOW) do
			quest:SetENpc(classId);
		end
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
		if (npcClassId == ENPC_DA_ZA) then
			-- Da Gu's tablet (1 = accepted).
			if (callClientFunction(player, "delegateEvent", player, quest, "processEvent_DAZA_Start") == 1) then
				player:AcceptQuest(quest);
			end
		end
	elseif (FOLLOW[npcClassId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, FOLLOW[npcClassId]);
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
