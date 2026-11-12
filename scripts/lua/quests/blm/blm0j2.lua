require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	A Time to Kill
Code:	Blm0j2
Id:		111262
Prereq: Blm0j1, Black Mage 35

At Milvaneth Sacrarium, Lalai hands down Ququruka's next prophecy: when a
new light shines from your testimony, you are to win the key that reseals
the Voidgate, by slaying the beast Daddy Longlegs west of Nophica's Wells
(processEventLALAIStart). Walking into its ground starts the fight
(SimpleContentBlm0j201). The quest ends there, away from any NPC
(onJobQuestComplete*).

Kazagg Chah (processEvent000_KAZAGGCHAH) waits in his cave west of Camp
Horizon.

]]

local SEQ_000 = 0;	-- Slay Daddy Longlegs west of Nophica's Wells.

local ENPC_LALAI			= 1060034;
local ENPC_KAZAGG_CHAH	= 1060036;
local LONGLEGS_TRIGGER	= 1090930;

local FIGHT = { 172, -1010.0, 90.8, 405.0, 3.1 };

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_LALAI, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ENPC_LALAI);
		quest:SetENpc(ENPC_KAZAGG_CHAH);
		quest:SetENpc(LONGLEGS_TRIGGER, QFLAG_PUSH, false, true);
	end
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	if (quest:GetSequence() == SEQ_ACCEPT) then
		if (npcClassId == ENPC_LALAI) then
			-- The second prophecy (1 = accepted).
			if (callClientFunction(player, "delegateEvent", player, quest, "processEventLALAIStart") == 1) then
				player:AcceptQuest(quest);
			end
		end
	elseif (npcClassId == ENPC_LALAI) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_LALAI");
	elseif (npcClassId == ENPC_KAZAGG_CHAH) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_KAZAGGCHAH");
	end
	player:EndEvent();
end

function onPush(player, quest, npc)
	if (quest:GetSequence() == SEQ_000 and npc:GetActorClassId() == LONGLEGS_TRIGGER) then
		questBattle.start(player, "Blm0j201", FIGHT, "Quest/SimpleQuestBattle/QuestDirectorWar0j101");
		return;
	end
	player:EndEvent();
end

-- Daddy Longlegs is down.
jobQuest.registerFight(111262, SEQ_000, function(player, quest)
	jobQuest.completeAway(player, quest);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end);

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
