require ("global")
require ("quest")

--[[

Quest Script

Name: 	Oil Crisis
Code: 	Gcl305
Id: 	111426
Prereq: Level 50, a sworn member of the Maelstrom (company_gate in quest_offers.rs).

The armorers of Naldiq & Vymelli's keep their plate from salt and rust with
an oil pressed from the seeds of the deadly nightshade, and the smiths have
given their whole stock to Admiral Merlwyb for her pistols. With the forges
working day and night for the coming invasion, Syngsmyd sends you to the
shores of Iron Lake to press the oil from the nightshades that grow
there, and rather aggressively at that.

The client script (gcl305) names the events; seed 161 places the
nightshades on the lake's southern shore.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Extract oil from deadly nightshades on the shores of Iron Lake.
SEQ_010	= 10;	-- Deliver the oil to Syngsmyd at Naldiq & Vymelli's.

-- Quest Actors
SYNGSMYD				= 1000177;
DEADLY_NIGHTSHADE		= 2202714;

-- Counters
COUNTER_NIGHTSHADES		= 0;
NIGHTSHADES_NEEDED		= 5;

-- Rewards (the client's reward sheet row: EXP tier 6 in slot 1, seals in slot 5)
REWARD_EXP				= 1322;
REWARD_SEALS			= 700;
COMPANY					= 1;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(SYNGSMYD, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(SYNGSMYD);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(SYNGSMYD, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();

	if (classId == SYNGSMYD and sequence == SEQ_ACCEPT) then
		-- the smiths, the Admiral's pistols, and the empty oil stock
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventSYNGSMYDStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (classId == SYNGSMYD and sequence == SEQ_000) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_000");
	elseif (classId == SYNGSMYD and sequence == SEQ_010) then
		-- one up on the smiths
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
	if (quest:GetSequence() ~= SEQ_000 or bnpc ~= DEADLY_NIGHTSHADE) then
		return;
	end
	-- the counter reads back stale within this hook: count this kill by hand
	local killed = quest:GetData():GetCounter(COUNTER_NIGHTSHADES) + 1;
	quest:GetData():IncCounter(COUNTER_NIGHTSHADES);
	if (killed >= NIGHTSHADES_NEEDED) then
		attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
		quest:StartSequence(SEQ_010);
	end
end

function getJournalInformation(player, quest)
	return NIGHTSHADES_NEEDED;
end

function getJournalMapMarkerList(player, quest)
end
