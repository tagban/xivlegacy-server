require ("global")
require ("quest")

--[[

Quest Script

Name: 	Risky Business
Code: 	Etc101
Id: 	110811
Prereq: Level 18, any class

The merchant Aistan has a delivery he daren't make himself, the Brass
Blades watching the goblins as they are: a fragment of fossil-fused dark
matter for his client, the goblin Mutamix Bubblypots, who has made camp
halfway up a cliff north of Ul'dah. Mutamix takes it ("now catalysts are
complete"), tells you of materia, and pays you the rest of Aistan's fee.

This quest opens the materia lessons (Etc102-Etc104), which need materia
creation and melding on the server and aren't scripted yet.

Mutamix had no spawn or class script; he stands on the cliff in Central
Thanalan at the position noted in quests/dft/DftWil.lua. ZAM has no page
for this quest, so the fee is an estimate.

Client script etc101: processEventAistanStart (offer), processEvent_000
(Aistan, while you deliver), processEvent_005 (Mutamix, the reward).
Journal steps 431-432.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Deliver the dark matter to Mutamix north of Ul'dah.

-- Actor Class Ids
ENPC_AISTAN			= 1001726;
ENPC_MUTAMIX		= 1001727;

-- Quest Markers
MRKR_MUTAMIX		= 11081101;

-- Rewards
REWARD_EXP			= 500;
REWARD_GIL			= 3000;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_AISTAN, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ENPC_MUTAMIX, QFLAG_REWARD);
		quest:SetENpc(ENPC_AISTAN);
	end
end

function onTalk(player, quest, npc)
	local seq = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (seq == SEQ_ACCEPT and classId == ENPC_AISTAN) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventAistanStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and classId == ENPC_AISTAN) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_000");
	elseif (seq == SEQ_000 and classId == ENPC_MUTAMIX) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_005");
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

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
	if (quest:getSequence() == SEQ_000) then
		return MRKR_MUTAMIX;
	end
end
