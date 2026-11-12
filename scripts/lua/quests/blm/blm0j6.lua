require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	Always Bet on Black
Code:	Blm0j6
Id:		111266
Prereq: Blm0j5, Black Mage 50

Da Za went home after the Solace of the Gods and learned only that his
ancestor Da Gu set out after it a hundred years ago (processEventStart).
Dozol Meloc's great-grandmother left home at the same time
(processEventDozol01), and Kazagg Chah's ancestor too; his last words
speak of the power of destruction woken in the most sacred of places
(processEventKazagg02). The linkpearl call is Lalai's: back at the
Sacrarium she tells you Ququruka made Barbatos with the beast tribes a
hundred years ago, and that his "prophecy" opens the Voidgate
(processEventLalai02). At Nald's Reflection, west of Camp Broken Water,
you face Barbatos (processEventNQ01 cutscene, SimpleContentBlm0j601);
after the fight (processEventNQ02 cutscene) you have the Wizard's Coat
(processEventAfget).

]]

local SEQ_000	= 0;	-- Speak to Dozol Meloc.
local SEQ_005	= 5;	-- Speak to Kazagg Chah.
local SEQ_010	= 10;	-- Return to Lalai at the Sacrarium.
local SEQ_015	= 15;	-- Stop Ququruka at Nald's Reflection.

local ENPC_LALAI		= 1060034;
local ENPC_KAZAGG_CHAH	= 1060036;
local ENPC_DOZOL_MELOC	= 1060037;
local ENPC_DA_ZA		= 1060038;
local REFLECTION_TRIGGER = 1090937;

local WIZARDS_COAT = 8032707;

local FIGHT = { 174, 1570.0, 360.9, 980.0, 0.8 };

local TALKS = {
	[SEQ_000] = { [ENPC_DA_ZA] = "processEventDaza01", [ENPC_KAZAGG_CHAH] = "processEventKazagg01", [ENPC_LALAI] = "processEventLalai01" },
	[SEQ_005] = { [ENPC_DA_ZA] = "processEventDaza02", [ENPC_DOZOL_MELOC] = "processEventDozol02" },
	[SEQ_010] = { [ENPC_DA_ZA] = "processEventDaza03", [ENPC_DOZOL_MELOC] = "processEventDozol03", [ENPC_KAZAGG_CHAH] = "processEventKazagg03" },
	[SEQ_015] = { [ENPC_DA_ZA] = "processEventDaza04", [ENPC_DOZOL_MELOC] = "processEventDozol04", [ENPC_KAZAGG_CHAH] = "processEventKazagg04", [ENPC_LALAI] = "processEventLalai03" },
};

-- Who moves the quest on in each step, and what they say.
local NEXT = {
	[SEQ_000] = { npc = ENPC_DOZOL_MELOC, fn = "processEventDozol01", to = SEQ_005 },
	[SEQ_005] = { npc = ENPC_KAZAGG_CHAH, fn = "processEventKazagg02", to = SEQ_010 },
	[SEQ_010] = { npc = ENPC_LALAI, fn = "processEventLalai02", to = SEQ_015 },
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_DA_ZA, QFLAG_TALK);
		return;
	end
	jobQuest.chatterMarkers(quest, TALKS, sequence);
	if (NEXT[sequence] ~= nil) then
		quest:SetENpc(NEXT[sequence].npc, QFLAG_TALK);
	elseif (sequence == SEQ_015) then
		quest:SetENpc(REFLECTION_TRIGGER, QFLAG_PUSH, false, true);
	end
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_DA_ZA) then
		-- The Solace of the Gods (1 = accepted).
		if (callClientFunction(player, "delegateEvent", player, quest, "processEventStart") == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (NEXT[seq] ~= nil and npcClassId == NEXT[seq].npc) then
		callClientFunction(player, "delegateEvent", player, quest, NEXT[seq].fn);
		quest:StartSequence(NEXT[seq].to);
	else
		jobQuest.chatter(player, quest, TALKS, seq, npcClassId);
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc)
	if (quest:GetSequence() == SEQ_015 and npc:GetActorClassId() == REFLECTION_TRIGGER) then
		-- Ququruka and Barbatos.
		callClientFunction(player, "delegateEvent", player, quest, "processEventNQ01");
		questBattle.start(player, "Blm0j601", FIGHT, "Quest/SimpleQuestBattle/QuestDirectorWar0j101");
		return;
	end
	player:EndEvent();
end

-- Barbatos is beaten.
jobQuest.registerFight(111266, SEQ_015, function(player, quest)
	callClientFunction(player, "delegateEvent", player, quest, "processEventNQ02");
	player:GetItemPackage(INVENTORY_NORMAL):AddItem(WIZARDS_COAT, 1, 1);
	callClientFunction(player, "delegateEvent", player, quest, "processEventAfget", WIZARDS_COAT);
	player:CompleteQuest(quest);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end);

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
