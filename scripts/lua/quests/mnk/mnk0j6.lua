require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	Return of the King...of Ruin
Code:	Mnk0j6
Id:		111226
Prereq: Mnk0j5, Monk 50

Erik's theorem is a success, but Widargelt answers neither letters nor
linkpearl; Erik is sure he has gone to Silvertear Falls, the one place
where the seventh chakra can be opened (processEventERIKStart). At the
falls you are too late (processEvent005 cutscene): Widargelt has opened it,
cut down a Garlean patrol and lost control of the power. Beat him to calm
it (SimpleContentMnk0j601, processEvent015 cutscene). Then speak to him:
he wanted the power only to take back Ala Mhigo, and he gives you the
Temple Cyclas (processEvent020, processEventClear).

Where the falls stand in Mor Dhona is a guess (near the Singing Shards);
Widargelt has a second spawn there for the last talk.

]]

local SEQ_000	= 0;	-- Hurry to Silvertear Falls.
local SEQ_010	= 10;	-- Speak to Widargelt.

local ENPC_ERIK			= 1060033;
local ENPC_WIDARGELT	= 1060032;
local FALLS_TRIGGER		= 1090919;

local TEMPLE_CYCLAS = 8032702;

local FIGHT = { 190, 570.0, 55.8, 190.0, 2.4 };

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_ERIK, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ENPC_ERIK);
		quest:SetENpc(ENPC_WIDARGELT);
		quest:SetENpc(FALLS_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_ERIK);
		quest:SetENpc(ENPC_WIDARGELT, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();
	if (seq == SEQ_ACCEPT) then
		if (npcClassId == ENPC_ERIK) then
			-- Widargelt has gone to Silvertear Falls (1 = accepted).
			if (callClientFunction(player, "delegateEvent", player, quest, "processEventERIKStart") == 1) then
				player:AcceptQuest(quest);
			end
		end
	elseif (seq == SEQ_000) then
		if (npcClassId == ENPC_ERIK) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000_ERIK_Follow");
		elseif (npcClassId == ENPC_WIDARGELT) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000_WIDARGELT_Follow");
		end
	elseif (seq == SEQ_010) then
		if (npcClassId == ENPC_WIDARGELT) then
			-- Ala Mhigo, and the Temple Cyclas.
			player:GetItemPackage(INVENTORY_NORMAL):AddItem(TEMPLE_CYCLAS, 1, 1);
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020", TEMPLE_CYCLAS);
			callClientFunction(player, "delegateEvent", player, quest, "processEventClear");
			player:CompleteQuest(quest);
		elseif (npcClassId == ENPC_ERIK) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020_ERIC_Follow");
		end
	end
	player:EndEvent();
end

function onPush(player, quest, npc)
	if (quest:GetSequence() == SEQ_000 and npc:GetActorClassId() == FALLS_TRIGGER) then
		-- Too late: the seventh chakra is open.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent005");
		questBattle.start(player, "Mnk0j601", FIGHT, "Quest/SimpleQuestBattle/QuestDirectorWar0j101");
		return;
	end
	player:EndEvent();
end

-- Widargelt is beaten and the power has calmed.
jobQuest.registerFight(111226, SEQ_000, function(player, quest)
	callClientFunction(player, "delegateEvent", player, quest, "processEvent015");
	quest:StartSequence(SEQ_010);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end);

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
