require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	Requiem for the Fallen
Code:	Brd0j6
Id:		111306
Prereq: Brd0j5, Bard 50

With the choral attire found, Jehantel is ready to visit the place where
his regiment fell, where Griffin Crossing meets the Coerthas highlands, and
sing them a requiem (processEventJEHANTELStart). Ixal hold the crossing;
walking onto the old battlefield starts the fight (SimpleContentBrd0j601).
Afterward Jehantel sings, takes up the bow again and hands you the last
piece of the choral attire (processEvent_010, processEventClear).

The client has no position for the battlefield; it stands in the north of
the North Shroud. Ixali cloudwalkers stand in for the foes.

]]

local SEQ_000	= 0;	-- Go with Jehantel to Griffin Crossing.

local ENPC_JEHANTEL		= 1060039;
local CROSSING_TRIGGER	= 1090955;

local CHORAL_SHIRT = 8032705;

local FIGHT = { 152, -1255.0, 20.0, -2245.0, 1.6 };

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
		quest:SetENpc(CROSSING_TRIGGER, QFLAG_PUSH, false, true);
	end
end

function onTalk(player, quest, npc, eventName)
	if (npc.GetActorClassId() == ENPC_JEHANTEL) then
		if (quest:GetSequence() == SEQ_ACCEPT) then
			-- The pilgrimage (1 = accepted).
			if (callClientFunction(player, "delegateEvent", player, quest, "processEventJEHANTELStart") == 1) then
				player:AcceptQuest(quest);
			end
		else
			-- Where Griffin Crossing meets the highlands.
			callClientFunction(player, "delegateEvent", player, quest, "processEventJEHANTELS_010_Follow");
		end
	end
	player:EndEvent();
end

function onPush(player, quest, npc)
	if (quest:GetSequence() == SEQ_000 and npc:GetActorClassId() == CROSSING_TRIGGER) then
		questBattle.start(player, "Brd0j601", FIGHT, "Quest/SimpleQuestBattle/QuestDirectorWar0j101");
		return;
	end
	player:EndEvent();
end

-- The crossing is clear: the requiem, and the last piece of the attire.
jobQuest.registerFight(111306, SEQ_000, function(player, quest)
	callClientFunction(player, "delegateEvent", player, quest, "processEvent_010");
	player:GetItemPackage(INVENTORY_NORMAL):AddItem(CHORAL_SHIRT, 1, 1);
	callClientFunction(player, "delegateEvent", player, quest, "processEventClear", CHORAL_SHIRT);
	player:CompleteQuest(quest);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end);

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
