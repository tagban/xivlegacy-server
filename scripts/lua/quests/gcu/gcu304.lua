require ("global")
require ("quest")

--[[

Quest Script

Name: 	When Alchemists Cry
Code: 	Gcu304
Id: 	111820
Prereq: Level 45, a sworn member of the Immortal Flames (company_gate in quest_offers.rs).

The Amalj'aa have fortified Zahar'ak in Southern Thanalan, and their war
drakes broke the Flames sent to besiege it. Berthar of the Phrontistery has
brewed the Tears of Nymeia, a poison deadly to scalekin, and asks you to mix
it into the drakes' feed. Jandonaut Fouillel, the Flame sergeant watching
Zahar'ak from Camp Broken Water, tells you where the fetid piles lie. When
you report back he asks after a great fire his dying friend Frederyk spoke
of, then guesses who poisoned the drakes: Berthar, Frederyk's friend, who
broke his healer's oath for vengeance. Jandonaut pays you all the same.

The client script (gcu304) names the events; seed 167 holds Jandonaut and
the three feed piles at Zahar'ak.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Speak with Jandonaut Fouillel at Camp Broken Water.
SEQ_010	= 10;	-- Mix the Tears of Nymeia into the drake feed at Zahar'ak.
SEQ_015	= 15;	-- Report to Jandonaut.

-- Quest Actors
BERTHAR					= 1001075;
JANDONAUT				= 1001699;	-- Flame Sergeant Jandonaut Fouillel

-- Triggers
FEED_PILES = {							-- each poisoned once, by flag
	[1090355] = 0,	-- by the entrance
	[1090356] = 1,	-- by the entrance
	[1090357] = 2,	-- among the structures beyond
};
FEED_TOTAL				= 3;

-- Key items
TEARS_OF_NYMEIA			= 11000412;	-- Berthar's poison

-- Counters
COUNTER_POISONED		= 0;

-- Rewards (the client's reward sheet row: EXP tier 5 in slot 1, seals in slot 5)
REWARD_EXP				= 1103;
REWARD_SEALS			= 700;
COMPANY					= 3;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(BERTHAR, QFLAG_TALK);
		return;
	end

	quest:SetENpc(BERTHAR);
	quest:SetENpc(JANDONAUT, (sequence == SEQ_000 and QFLAG_TALK) or (sequence == SEQ_015 and QFLAG_REWARD) or QFLAG_NONE);
	if (sequence == SEQ_010) then
		for pile in pairs(FEED_PILES) do
			quest:SetENpc(pile, QFLAG_PUSH, false, true);
		end
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();

	if (classId == BERTHAR and sequence == SEQ_ACCEPT) then
		-- the war drakes of Zahar'ak, and the Tears of Nymeia
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventBERTHARStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
			player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(TEARS_OF_NYMEIA, 1, 1);
		end
	elseif (classId == BERTHAR) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_000");
	elseif (classId == JANDONAUT and sequence == SEQ_000) then
		-- Zahar'ak entrenched, and where the drake feed lies
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_005");
		quest:StartSequence(SEQ_010);
	elseif (classId == JANDONAUT and sequence == SEQ_010) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_005_01");
	elseif (classId == JANDONAUT and sequence == SEQ_015) then
		-- the great fire, and Berthar's broken oath
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_015");
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(TEARS_OF_NYMEIA, 1);
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

function onPush(player, quest, npc)
	local classId = npc:GetActorClassId();
	local flag = FEED_PILES[classId];

	if (flag ~= nil and quest:GetSequence() == SEQ_010) then
		if (quest:GetData():GetFlag(flag)) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_010_02");
		elseif (callClientFunction(player, "delegateEvent", player, quest, "processEvent_010") == 1) then
			quest:GetData():SetFlag(flag);
			-- the counter reads back stale within this hook: count this one by hand
			local poisoned = quest:GetData():GetCounter(COUNTER_POISONED) + 1;
			quest:GetData():IncCounter(COUNTER_POISONED);
			-- You poisoned the drake feed! (poisoned of total)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_010_01", poisoned, FEED_TOTAL);
			if (poisoned >= FEED_TOTAL) then
				attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
				quest:StartSequence(SEQ_015);
			end
		end
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
