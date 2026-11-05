require ("global")
require ("quest")
require ("questbattle")

--[[

Quest Script

Name: 	Best Flower Ever
Code: 	Etc1u9
Id: 	110684
Prereq: Level 10, any class

Sasapano, a Golden Bazaar merchant, fled a flock of rabid dodos and lost
his Azeyma rose by a cave where he saw Garlean agents. Clear the dodos from
the valley southeast of him (stepping onto the spot starts the fight,
SimpleContentEtc1u901 / the client's SimpleQuestBattle QuestDirectorEtc1u901),
and he sneaks in after his rose. Reward 5,000 gil (ZAM) and experience.

Sasapano had no spawn or class script; he stands at the Golden Bazaar at
the position noted in quests/dft/DftWil.lua. The dodos' valley lies to the
east (ZAM: rabid dodos at map (40,20)).

Client script etc1u9: processEventSasapanoStart (offer), processEvent000
(while the dodos roam), processEvent005 (the rose, and the reward). Journal
steps 301-303.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Kill the rabid dodos in the valley.
SEQ_005	= 5;	-- Return to Sasapano.

-- Actor Class Ids
ENPC_SASAPANO		= 1001317;
VALLEY_TRIGGER		= 1090602;

-- Quest Markers
MRKR_VALLEY			= 11068401;
MRKR_SASAPANO		= 11068402;

-- Places: the fight, and where a win or a loss sets you down.
FIGHT				= {171, 1320.0, 279.77, -1094.0, 0.0};

-- Rewards
REWARD_EXP			= 300;
REWARD_GIL			= 5000;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_SASAPANO, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(VALLEY_TRIGGER, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_SASAPANO);
	elseif (sequence == SEQ_005) then
		quest:SetENpc(ENPC_SASAPANO, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc)
	local seq = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (seq == SEQ_ACCEPT and classId == ENPC_SASAPANO) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventSasapanoStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and classId == ENPC_SASAPANO) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000");
	elseif (seq == SEQ_005 and classId == ENPC_SASAPANO) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent005");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddGil(REWARD_GIL);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onPush(player, quest, npc)
	if (quest:getSequence() == SEQ_000 and npc:GetActorClassId() == VALLEY_TRIGGER) then
		questBattle.start(player, "Etc1u901", FIGHT);
		return;
	end
	player:EndEvent();
end

-- QuestDirectorEtc1u901, once the dodos are down.
function winEtc1u9Fight(player, quest)
	attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
	quest:StartSequence(SEQ_005);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end

-- SimpleContentEtc1u901, on a loss.
function loseEtc1u9Fight(player, timedOut)
	questBattle.leave(player, FIGHT);
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_000) then
		return MRKR_VALLEY;
	elseif (seq == SEQ_005) then
		return MRKR_SASAPANO;
	end
end
