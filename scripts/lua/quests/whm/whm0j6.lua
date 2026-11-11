require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	The Chorus of Cataclysm
Code:	Whm0j6
Id:		111246
Prereq: Whm0j5, White Mage 50

Oha-Sok has gone back into the Twelveswood and the elementals' keening is
growing. Raya-O-Senna feels it strongest southwest of Camp Bentbranch and
sends you there (processEventStart). The angry elementals rise as you
arrive (processEventCutSceneBeforeBattle cutscene, SimpleContentWhm0j601).
When all seems lost Oha-Sok saves you and becomes the last piece of the
garb of succor (processEventNQ cutscene, processEvent_getAF_info). Back at
the cave Raya-O hears it all (processEventClear, processEventAfget).

The angry elementals' battle classes aren't known; wind and earth
elementals stand in.

]]

local SEQ_000	= 0;	-- Calm the elementals southwest of Camp Bentbranch.
local SEQ_010	= 10;	-- Return to Raya-O-Senna.

local ENPC_RAYA_O_SENNA	= 1001570;
local KEENING_TRIGGER	= 1090928;

local HEALERS_ROBE = 8032706;

local FIGHT = { 150, 190.0, 3.6, -515.0, 0.0 };

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
		quest:SetENpc(KEENING_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_RAYA_O_SENNA, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc, eventName)
	local seq = quest:GetSequence();
	if (npc.GetActorClassId() == ENPC_RAYA_O_SENNA) then
		if (seq == SEQ_ACCEPT) then
			-- The keening southwest of Bentbranch (1 = accepted).
			if (callClientFunction(player, "delegateEvent", player, quest, "processEventStart") == 1) then
				player:AcceptQuest(quest);
			end
		elseif (seq == SEQ_000) then
			callClientFunction(player, "delegateEvent", player, quest, "processEventRyaoAfter");
		elseif (seq == SEQ_010) then
			callClientFunction(player, "delegateEvent", player, quest, "processEventClear");
			callClientFunction(player, "delegateEvent", player, quest, "processEventAfget");
			player:CompleteQuest(quest);
		end
	end
	player:EndEvent();
end

function onPush(player, quest, npc)
	if (quest:GetSequence() == SEQ_000 and npc:GetActorClassId() == KEENING_TRIGGER) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventCutSceneBeforeBattle");
		questBattle.start(player, "Whm0j601", FIGHT, "Quest/SimpleQuestBattle/QuestDirectorWar0j101");
		return;
	end
	player:EndEvent();
end

-- Oha-Sok saves you and becomes the robe.
jobQuest.registerFight(111246, SEQ_000, function(player, quest)
	callClientFunction(player, "delegateEvent", player, quest, "processEventNQ");
	player:GetItemPackage(INVENTORY_NORMAL):AddItem(HEALERS_ROBE, 1, 1);
	callClientFunction(player, "delegateEvent", player, quest, "processEvent_getAF_info");
	quest:StartSequence(SEQ_010);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end);

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
