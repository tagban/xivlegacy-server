require ("global")
require ("quest")
require ("jobquest")

--[[

Quest Script

Name:	Double Dragoon
Code:	Drg0j4
Id:		111324
Prereq: Drg0j3, Dragoon 45

Estinien asks to meet Ser Alberic and you in the foothills southwest of
Skyfire Locks (processEvent_ALBERIC_Start). There he says the Eye is not
why the dragons stir: Nidhogg is waking, and he means to face it himself
(processEvent_NQ_Drg0j410). Alberic then asks you to gather the drachen
mail (processEvent_ALBERIC_Guidance): the Aurum Vale, the cave north of
Camp Brittlebark, the U'Ghamaro Mines and the cave north of Camp Bluefog.
Each place gives up its piece (processEvent_getAF_info); with the fourth
the quest is done.

The client has no positions for the meeting or the four places; the
meeting stands west of Camp Glory, and the piece found at each place is a
guess. The Bluefog point stands on open ground just north of the camp:
the client has no walkable floor where the cave would be. The mail comes
in Drg0j6.

]]

local SEQ_000 = 0;	-- Meet Estinien southwest of Skyfire Locks.
local SEQ_010 = 10;	-- Find the four pieces of the drachen mail.

local ENPC_ALBERIC		= 1060040;
local MEETING_TRIGGER	= 1090959;

-- Resting place (push circle) -> the piece found there and its quest flag.
local PIECES = {
	[1090960] = { item = 8013504, flag = 0 }, -- the Aurum Vale: Drachen Armet
	[1090961] = { item = 8071404, flag = 1 }, -- north of Camp Brittlebark: Drachen Gauntlets
	[1090962] = { item = 8051404, flag = 2 }, -- the U'Ghamaro Mines: Drachen Breeches
	[1090963] = { item = 8081804, flag = 3 }, -- north of Camp Bluefog: Drachen Greaves
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_ALBERIC, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ENPC_ALBERIC);
		quest:SetENpc(MEETING_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_ALBERIC);
		local data = quest:GetData();
		for classId, piece in pairs(PIECES) do
			if (not data:GetFlag(piece.flag)) then
				quest:SetENpc(classId, QFLAG_PUSH, false, true);
			end
		end
	end
end

function onTalk(player, quest, npc, eventName)
	if (npc.GetActorClassId() == ENPC_ALBERIC) then
		if (quest:GetSequence() == SEQ_ACCEPT) then
			-- Estinien would trade words (1 = accepted).
			if (callClientFunction(player, "delegateEvent", player, quest, "processEvent_ALBERIC_Start") == 1) then
				player:AcceptQuest(quest);
			end
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_ALBERIC_Follow");
		end
	end
	player:EndEvent();
end

function onPush(player, quest, npc)
	local classId = npc:GetActorClassId();
	local seq = quest:GetSequence();
	if (seq == SEQ_000 and classId == MEETING_TRIGGER) then
		-- Estinien's resolve, then the drachen mail.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_NQ_Drg0j410");
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_ALBERIC_Guidance");
		quest:StartSequence(SEQ_010);
	elseif (seq == SEQ_010 and PIECES[classId] ~= nil) then
		local piece = PIECES[classId];
		local data = quest:GetData();
		if (not data:GetFlag(piece.flag)) then
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
	end
	player:EndEvent();
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
