require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	Hearing Voices
Code:	Blm0j1
Id:		111261
Prereq: Thaumaturge 30, a second class at 15 (Job 1: the black mage)

Yayake of Arrzaneth Ossuary tells of Ququruka, a prisoner in the Marasaja
Pit who claims Nald'thal speaks to him: an adventurer of your name will
slay the guano gnats of Western Thanalan and win a legendary gem
(processEventYayakeStart). Walking among the gnats near the Copperbell
Mines entrance, north of Nophica's Wells, starts the fight
(SimpleContentBlm0j101). With the gnats dead, the Amalj'aa Kazagg Chah
hands you the Gem of Shatotto (processEvent010 cutscene). Back at the
Ossuary the gem awakens and you take up the black (processEvent020
cutscene, processEventClear).

]]

local SEQ_000	= 0;	-- Slay the guano gnats north of Nophica's Wells.
local SEQ_010	= 10;	-- Return to Yayake at Arrzaneth Ossuary.

local ENPC_YAYAKE	= 1000846;
local GNAT_TRIGGER	= 1090929;

local JOB_BLACK_MAGE = 26;

local FIGHT = { 172, -880.0, 88.4, 250.0, 0.0 };

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_YAYAKE, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ENPC_YAYAKE);
		quest:SetENpc(GNAT_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_YAYAKE, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc, eventName)
	local seq = quest:GetSequence();
	if (npc.GetActorClassId() == ENPC_YAYAKE) then
		if (seq == SEQ_ACCEPT) then
			-- Ququruka's prophecy (1 = accepted).
			if (callClientFunction(player, "delegateEvent", player, quest, "processEventYayakeStart") == 1) then
				player:AcceptQuest(quest);
			end
		elseif (seq == SEQ_000) then
			callClientFunction(player, "delegateEvent", player, quest, "processEventYayake000Follow");
		elseif (seq == SEQ_010) then
			-- The gem awakens: the Soul of the Black Mage.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
			jobQuest.giveSoulCrystal(player, JOB_BLACK_MAGE);
			callClientFunction(player, "delegateEvent", player, quest, "processEventClear", jobQuest.SOUL_CRYSTAL[JOB_BLACK_MAGE]);
			player:CompleteQuest(quest);
		end
	end
	player:EndEvent();
end

function onPush(player, quest, npc)
	if (quest:GetSequence() == SEQ_000 and npc:GetActorClassId() == GNAT_TRIGGER) then
		questBattle.start(player, "Blm0j101", FIGHT, "Quest/SimpleQuestBattle/QuestDirectorWar0j101");
		return;
	end
	player:EndEvent();
end

-- The gnats are dead; Kazagg Chah brings the Gem of Shatotto.
jobQuest.registerFight(111261, SEQ_000, function(player, quest)
	callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
	quest:StartSequence(SEQ_010);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end);

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
