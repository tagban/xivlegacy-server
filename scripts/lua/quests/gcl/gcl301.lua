require ("global")
require ("quest")

--[[

Quest Script

Name: 	The Cove
Code: 	Gcl301
Id: 	111417
Prereq: Level 25, a sworn member of the Maelstrom (company_gate in quest_offers.rs).

To feed the Maelstrom's swelling ranks, the Fishermen's Guild must double its
daily catch. Clifton means to drive fish into hidden nets with a curtain of
bubbles, but first the shores of a secluded cove northwest of Aleport must be
cleared of the dart slugs that infest them. Back at the guild Clifton tells
how a babe of a fish changed his mind: the sea's balance comes first, and the
Barrel's feeding ponds will grow instead.

The client script (gcl301) names the events; seed 157 places the dart slugs
on the sandy cove west of Aleport.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Slay dart slugs in the cove northwest of Aleport.
SEQ_010	= 10;	-- Return to Clifton at the Fishermen's Guild.

-- Quest Actors
CLIFTON					= 1000199;
DART_SLUG				= 2204211;

-- Counters
COUNTER_SLUGS			= 0;
SLUGS_NEEDED			= 6;

-- Rewards (the client's reward sheet row: EXP tier 7 in slot 1, seals in slot 5)
REWARD_EXP				= 1541;
REWARD_SEALS			= 300;
COMPANY					= 1;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(CLIFTON, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(CLIFTON);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(CLIFTON, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();

	if (classId == CLIFTON and sequence == SEQ_ACCEPT) then
		-- the bubble net, and the slugs in the way
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventCLIFTONStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (classId == CLIFTON and sequence == SEQ_000) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_000");
	elseif (classId == CLIFTON and sequence == SEQ_010) then
		-- the sea's balance, and the Barrel's feeding ponds
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 5);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddSeals(COMPANY, REWARD_SEALS);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onKillBNpc(player, quest, bnpc)
	if (quest:GetSequence() ~= SEQ_000 or bnpc ~= DART_SLUG) then
		return;
	end
	-- the counter reads back stale within this hook: count this kill by hand
	local killed = quest:GetData():GetCounter(COUNTER_SLUGS) + 1;
	quest:GetData():IncCounter(COUNTER_SLUGS);
	if (killed >= SLUGS_NEEDED) then
		attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
		quest:StartSequence(SEQ_010);
	end
end

function getJournalInformation(player, quest)
	return SLUGS_NEEDED;
end

function getJournalMapMarkerList(player, quest)
end
