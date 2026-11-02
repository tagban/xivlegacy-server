require ("global")
require ("quest")

--[[

Quest Script

Name: 	Woes of the Botanist
Code: 	Gcg303
Id: 	111619
Prereq: Level 40, a sworn member of the Order of the Twin Adder (company_gate in quest_offers.rs).

Enie of the Botanists' Guild needs a rare herb to save her mentor Aldous,
grievously wounded while leading the Blue Badgers. The only field where it
grows, south and east of Humblehearth, is overrun with monsters. Clear
them, and Enie finds the herbs eaten and the field choked with weeds. A
fretful moogle blames her for sprinkling strange stuff on the herbs, and
leaves you a message for her. Enie realizes her Ul'dahn fertilizer drew
the beasts; once she sees that thinning the weeds restores the balance, you
pass on the moogle's secret: blend the weed with the herb's roots for a
still more potent medicine.

The client script (gcg303) names the events; seed 164 holds the ladybugs,
Enie and the moogle at the field.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Slay the monsters south and east of Humblehearth.
SEQ_005	= 5;	-- Speak with Enie at the field.
SEQ_010	= 10;	-- Speak with the moogle.
SEQ_015	= 15;	-- Relay the moogle's message to Enie.

-- Quest Actors
ENIE					= 1001806;
MOOGLE					= 1001838;	-- Fretful moogle
LADYBUG					= 2103904;

-- Enie's second spawn stands at the field; the guild one only repeats her plea
FIELD_ZONE				= 150;

-- Counters
COUNTER_BEASTS			= 0;
BEASTS_NEEDED			= 6;

-- Rewards (the client's reward sheet row: EXP tier 6 in slot 1, seals in slot 5)
REWARD_EXP				= 1322;
REWARD_SEALS			= 1000;
COMPANY					= 2;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENIE, QFLAG_TALK);
		return;
	end

	quest:SetENpc(ENIE, (sequence == SEQ_005 or sequence == SEQ_015) and QFLAG_TALK or QFLAG_NONE);
	if (sequence >= SEQ_010) then
		quest:SetENpc(MOOGLE, sequence == SEQ_010 and QFLAG_TALK or QFLAG_NONE);
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();
	local atField = player:GetZoneID() == FIELD_ZONE;

	if (classId == ENIE and sequence == SEQ_ACCEPT) then
		-- Master Aldous, and the herb that might save him
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (classId == ENIE and atField and sequence == SEQ_005) then
		-- the herbs eaten, the field thick with weeds
		callClientFunction(player, "delegateEvent", player, quest, "processEventEnie");
		quest:StartSequence(SEQ_010);
	elseif (classId == ENIE and atField and sequence == SEQ_015) then
		-- the fertilizer, and the moogle's secret
		callClientFunction(player, "delegateEvent", player, quest, "processEventClear");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 5);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddSeals(COMPANY, REWARD_SEALS);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	elseif (classId == ENIE and not atField) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventStartAfter");
	elseif (classId == MOOGLE and sequence == SEQ_010) then
		-- a message for Aldous's pupil
		callClientFunction(player, "delegateEvent", player, quest, "processEventMog");
		quest:StartSequence(SEQ_015);
	elseif (classId == MOOGLE) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventKupo");
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onKillBNpc(player, quest, bnpc)
	if (quest:GetSequence() ~= SEQ_000 or bnpc ~= LADYBUG) then
		return;
	end
	-- the counter reads back stale within this hook: count this kill by hand
	local killed = quest:GetData():GetCounter(COUNTER_BEASTS) + 1;
	quest:GetData():IncCounter(COUNTER_BEASTS);
	if (killed >= BEASTS_NEEDED) then
		attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
		quest:StartSequence(SEQ_005);
	end
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
