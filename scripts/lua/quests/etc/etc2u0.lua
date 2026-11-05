require ("global")
require ("quest")
require ("questbattle")

--[[

Quest Script

Name: 	The Unheard Horizon
Code: 	Etc2u0
Id: 	110685
Prereq: Level 20, any class

Gegeissa, the Lalafell sentry at the Gate of Nald, frets that Thanalan's
oversized beasts are scaring off the carrier chocobos. Walk out to the
outskirts of Camp Horizon in Western Thanalan: stepping onto the spot
starts the fight (SimpleContentEtc2u001, the client's SimpleQuestBattle
QuestDirectorEtc2u001) with two coblyns, a spriggan and a feral dodo. Then
boast of it to Gegeissa: 100 wind shards (ZAM) and experience.

Client script etc2u0: processEventStart (offer), processEventFree (while
the beasts still roam), processEventClear (the reward). Journal steps 304-306.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Kill the beasts near Camp Horizon.
SEQ_010	= 10;	-- Report back to Gegeissa at the Gate of Nald.

-- Actor Class Ids
ENPC_GEGEISSA		= 1001424;
HORIZON_TRIGGER		= 1090600;

-- Quest Markers
MRKR_HORIZON		= 11068501;
MRKR_GEGEISSA		= 11068502;

-- Places: the fight, and where a win or a loss sets you down (outside the
-- trigger circle).
FIGHT				= {172, -1340.0, 55.84, -250.0, 0.0};

-- Rewards
REWARD_EXP			= 1280;
REWARD_WIND_SHARD	= 1000005;
REWARD_SHARDS		= 100;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_GEGEISSA, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(HORIZON_TRIGGER, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_GEGEISSA);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_GEGEISSA, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc)
	local seq = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (seq == SEQ_ACCEPT and classId == ENPC_GEGEISSA) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and classId == ENPC_GEGEISSA) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventFree");
	elseif (seq == SEQ_010 and classId == ENPC_GEGEISSA) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventClear");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:GetItemPackage(INVENTORY_CURRENCY):AddItem(REWARD_WIND_SHARD, REWARD_SHARDS, 1);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onPush(player, quest, npc)
	if (quest:getSequence() == SEQ_000 and npc:GetActorClassId() == HORIZON_TRIGGER) then
		questBattle.start(player, "Etc2u001", FIGHT);
		return;
	end
	player:EndEvent();
end

-- QuestDirectorEtc2u001, once every beast is down.
function winEtc2u0Fight(player, quest)
	attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
	quest:StartSequence(SEQ_010);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end

-- SimpleContentEtc2u001, on a loss.
function loseEtc2u0Fight(player, timedOut)
	questBattle.leave(player, FIGHT);
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_000) then
		return MRKR_HORIZON;
	elseif (seq == SEQ_010) then
		return MRKR_GEGEISSA;
	end
end
