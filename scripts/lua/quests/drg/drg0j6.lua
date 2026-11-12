require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	Into the Dragon's Maw
Code:	Drg0j6
Id:		111326
Prereq: Drg0j5, Dragoon 50

Word comes from Estinien: Nidhogg is on the move, and he bids you come to
the Griffin Bridge southeast of the Gates of Judgement
(processEventALBERICStart). At the bridge Estinien scorns Alberic, and the
dragon's darkness falls on them (processEvent010); its spawn attack, and
walking onto the bridge starts the fight (SimpleContentDrg0j601). Once the
darkness lifts (processEvent020), you return with Alberic to the Gates of
Judgement, where he gives you the drachen mail (processEvent030).

The client has no position for the Griffin Bridge; it stands southeast of
Ser Alberic. Lava drakes stand in for the dragon's spawn.
processEvent015 and processEvent025 aren't used.

]]

local SEQ_000	= 0;	-- Go to the Griffin Bridge.
local SEQ_010	= 10;	-- Return to the Gates of Judgement.

local ENPC_ALBERIC		= 1060040;
local BRIDGE_TRIGGER	= 1090965;

local DRACHEN_MAIL = 8032704;

local FIGHT = { 145, 1515.0, 229.0, 490.0, 1.6 };

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
		quest:SetENpc(BRIDGE_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_ALBERIC, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc, eventName)
	local seq = quest:GetSequence();
	if (npc.GetActorClassId() == ENPC_ALBERIC) then
		if (seq == SEQ_ACCEPT) then
			-- Estinien's urgent message (1 = accepted).
			if (callClientFunction(player, "delegateEvent", player, quest, "processEventALBERICStart") == 1) then
				player:AcceptQuest(quest);
			end
		elseif (seq == SEQ_000) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000");
		elseif (seq == SEQ_010) then
			-- Haldrath's likeness, and the drachen mail.
			player:GetItemPackage(INVENTORY_NORMAL):AddItem(DRACHEN_MAIL, 1, 1);
			callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
			player:CompleteQuest(quest);
		end
	end
	player:EndEvent();
end

function onPush(player, quest, npc)
	if (quest:GetSequence() == SEQ_000 and npc:GetActorClassId() == BRIDGE_TRIGGER) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		questBattle.start(player, "Drg0j601", FIGHT, "Quest/SimpleQuestBattle/QuestDirectorWar0j101");
		return;
	end
	player:EndEvent();
end

-- The darkness lifts.
jobQuest.registerFight(111326, SEQ_000, function(player, quest)
	callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
	quest:StartSequence(SEQ_010);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end);

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
