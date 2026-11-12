require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	Doing It the Bard Way
Code:	Brd0j4
Id:		111304
Prereq: Brd0j3, Bard 45

Jehantel sings you the Ballad of the Vainglorious Fool, an archer whose
pride cost his regiment their lives, and asks you to escort him to a place
north of Hyrstmill in the North Shroud (processEventStart; the hint before
level 45 is processEventStartBefore). There he calls on Althyk to show the
battles of old, and the Ixal van falls upon you (processEventNQ01, the
fight in SimpleContentBrd0j401). Afterward Jehantel confesses that he was
the fool of the ballad (processEventNQ03) and a new song stirs in you
(processEventClear01). The quest ends there, away from camp.

The client has no position for the place north of Hyrstmill; it stands on
the flat ground north of Camp Emerald Moss. Ixali limbcutters stand in for
the phantom van. processEventNQ02 and processEventClear02 replay the same
scenes and aren't used.

]]

local SEQ_000	= 0;	-- Escort Jehantel north of Hyrstmill.

local ENPC_JEHANTEL	= 1060039;
local VAN_TRIGGER	= 1090950;

local FIGHT = { 152, -1035.0, 19.9, -1985.0, 3.1 };

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
		quest:SetENpc(VAN_TRIGGER, QFLAG_PUSH, false, true);
	end
end

function onTalk(player, quest, npc, eventName)
	if (npc.GetActorClassId() == ENPC_JEHANTEL) then
		if (quest:GetSequence() == SEQ_ACCEPT) then
			-- The Ballad of the Vainglorious Fool (1 = accepted).
			if (callClientFunction(player, "delegateEvent", player, quest, "processEventStart") == 1) then
				player:AcceptQuest(quest);
			end
		else
			-- North of Hyrstmill, young one.
			callClientFunction(player, "delegateEvent", player, quest, "processEventJehantel");
		end
	end
	player:EndEvent();
end

function onPush(player, quest, npc)
	if (quest:GetSequence() == SEQ_000 and npc:GetActorClassId() == VAN_TRIGGER) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventNQ01");
		questBattle.start(player, "Brd0j401", FIGHT, "Quest/SimpleQuestBattle/QuestDirectorWar0j101");
		return;
	end
	player:EndEvent();
end

-- The van is down; Jehantel tells the truth of the ballad.
jobQuest.registerFight(111304, SEQ_000, function(player, quest)
	callClientFunction(player, "delegateEvent", player, quest, "processEventNQ03");
	callClientFunction(player, "delegateEvent", player, quest, "processEventClear01");
	player:CompleteQuest(quest);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end);

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
