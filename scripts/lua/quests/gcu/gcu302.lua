require ("global")
require ("quest")

--[[

Quest Script

Name: 	Different Strokes
Code: 	Gcu302
Id: 	111818
Prereq: Level 25, a sworn member of the Immortal Flames (company_gate in quest_offers.rs).

Bad blood runs between the Ul'dahns and the Ala Mhigans of the Immortal
Flames. The Ul'dahns of the new Beastcleavers marched out without telling
their Ala Mhigan comrades where, and Galeren of the Coliseum asks you to
tell Flame Sergeant Cotter on Pearl Lane. Cotter knows the route northeast
of Camp Drybone from the Dead March, and sends you to turn the Ul'dahns
back. Hellhounds fall upon you there; Flame Lieutenant Westin's
Beastcleavers arrive after and, hearing Cotter's warning, turn back.
Galeren hopes the debt the Ul'dahns now owe may be a step towards peace.

The client script (gcu302) names the events; seed 154 holds Cotter, the
Beastcleavers and the hounds.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Find Sergeant Cotter on Pearl Lane.
SEQ_005	= 5;	-- Warn the Beastcleavers northeast of Camp Drybone (slay the hounds there).
SEQ_015	= 15;	-- Speak with Lieutenant Westin.
SEQ_020	= 20;	-- Report to Galeren at the Coliseum.

-- Quest Actors
GALEREN					= 1000963;
COTTER					= 1001685;	-- Flame Sergeant Third Class Adalbert Cotter
WESTIN					= 1001686;	-- Flame Lieutenant Westin
SALPA_HAZALPA			= 1001687;
GOODWIFE				= 1001688;
HELLHOUND				= 2109801;

-- The Beastcleavers' privates: each one's talk.
PRIVATES = {
	[SALPA_HAZALPA]	= "processEvent_015_01",
	[GOODWIFE]		= "processEvent_015_03",	-- "speak with Lieutenant Westin"
};

-- Counters
COUNTER_HOUNDS			= 0;
HOUNDS_NEEDED			= 3;

-- Rewards (the client's reward sheet row: EXP tier 7 in slot 1, seals in slot 5)
REWARD_EXP				= 1541;
REWARD_SEALS			= 300;
COMPANY					= 3;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(GALEREN, QFLAG_TALK);
		return;
	end

	quest:SetENpc(GALEREN, sequence == SEQ_020 and QFLAG_REWARD or QFLAG_NONE);
	quest:SetENpc(COTTER, sequence == SEQ_000 and QFLAG_TALK or QFLAG_NONE);
	if (sequence >= SEQ_005) then
		quest:SetENpc(WESTIN, sequence == SEQ_015 and QFLAG_TALK or QFLAG_NONE);
		for private in pairs(PRIVATES) do
			quest:SetENpc(private);
		end
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();

	if (classId == GALEREN and sequence == SEQ_ACCEPT) then
		-- the Beastcleavers, and the rift in the Flames
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventGALERENStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (classId == GALEREN and sequence == SEQ_020) then
		-- a debt the Ul'dahns owe
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_020");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 5);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddSeals(COMPANY, REWARD_SEALS);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	elseif (classId == GALEREN) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_000");
	elseif (classId == COTTER and sequence == SEQ_000) then
		-- the Dead March route
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_005");
		quest:StartSequence(SEQ_005);
	elseif (classId == COTTER) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_005_1");
	elseif (classId == WESTIN and sequence == SEQ_015) then
		-- Cotter's warning turns the Beastcleavers back
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_015");
		quest:StartSequence(SEQ_020);
	elseif (PRIVATES[classId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, PRIVATES[classId]);
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onKillBNpc(player, quest, bnpc)
	if (quest:GetSequence() ~= SEQ_005 or bnpc ~= HELLHOUND) then
		return;
	end
	-- the counter reads back stale within this hook: count this kill by hand
	local killed = quest:GetData():GetCounter(COUNTER_HOUNDS) + 1;
	quest:GetData():IncCounter(COUNTER_HOUNDS);
	if (killed >= HOUNDS_NEEDED) then
		quest:StartSequence(SEQ_015);
	end
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
