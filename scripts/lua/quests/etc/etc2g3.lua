require ("global")
require ("quest")
require ("questbattle")

--[[

Quest Script

Name: 	Hunting the Hunters
Code: 	Etc2g3
Id: 	110667
Prereq: Level 24, any class

O'dhinek of the Gods' Quiver tells you a band of Ixal clawed one of the
Quiver's recruits nearly to death. The scouts lost their trail near
Quarrymill in the South Shroud; stepping into the clearing west of the
hamlet starts the fight (SimpleContentEtc2g301, the client's
SimpleQuestBattle QuestDirectorEtc2g301) with four Ixali bravos (ZAM: two
waves of two). Then report to O'dhinek. Reward 100 steel arrows (the
client's reward table, data/01/03/05/61.DAT) and 1,751 experience (ZAM).

Client script etc2g3: processEventODhinekStart (offer), processEvent000
(while you hunt), processEvent010 (the reward). Journal steps 248-250.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Hunt down the Ixal near Quarrymill.
SEQ_010	= 10;	-- Report back to O'dhinek.

-- Actor Class Ids
ENPC_ODHINEK		= 1000829;
CLEARING_TRIGGER	= 1090606;

-- Quest Markers
MRKR_CLEARING		= 11066701;
MRKR_ODHINEK		= 11066702;

-- Places: the fight, and where a win or a loss sets you down (outside the
-- trigger circle).
FIGHT				= {154, 1285.0, -11.48, 875.0, 0.0};

-- Rewards
REWARD_EXP			= 1751;
REWARD_ARROWS		= 3920003;
REWARD_ARROWS_QTY	= 100;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_ODHINEK, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(CLEARING_TRIGGER, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_ODHINEK);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_ODHINEK, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc)
	local seq = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (seq == SEQ_ACCEPT and classId == ENPC_ODHINEK) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventODhinekStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and classId == ENPC_ODHINEK) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000");
	elseif (seq == SEQ_010 and classId == ENPC_ODHINEK) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:GetItemPackage(INVENTORY_NORMAL):AddItem(REWARD_ARROWS, REWARD_ARROWS_QTY, 1);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onPush(player, quest, npc)
	if (quest:getSequence() == SEQ_000 and npc:GetActorClassId() == CLEARING_TRIGGER) then
		questBattle.start(player, "Etc2g301", FIGHT);
		return;
	end
	player:EndEvent();
end

-- QuestDirectorEtc2g301, once every Ixal is down.
function winEtc2g3Fight(player, quest)
	attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
	quest:StartSequence(SEQ_010);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end

-- SimpleContentEtc2g301, on a loss.
function loseEtc2g3Fight(player, timedOut)
	questBattle.leave(player, FIGHT);
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_000) then
		return MRKR_CLEARING;
	elseif (seq == SEQ_010) then
		return MRKR_ODHINEK;
	end
end
