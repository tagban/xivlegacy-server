require ("global")
require ("quest")

--[[

Quest Script

Name: 	Prying Eyes
Code: 	Gcu301
Id: 	111817
Prereq: Level 25, a sworn member of the Immortal Flames (company_gate in quest_offers.rs).

The Immortal Flames have asked Eshtaime's Lapidaries for an accessory to
issue to their soldiers. Lefchild would rather set it with the rare, bright
coblyn eye than the common one, and sends you to the mesas east of Camp
Horizon with a chunk of omnomite to lure the beasts: slay up to thirty
coblyns and one may yield the rare stone. Lefchild guesses from your tale
that any coblyn's eye crystallizes so when it sees its kin slain.

The client script (gcu301) names the events (its start event is still
called processEventCLIFTONStart); seed 153 places the coblyns.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Slay coblyns on the mesas east of Camp Horizon.
SEQ_010	= 10;	-- Bring the bright eye to Lefchild.

-- Quest Actors
LEFCHILD				= 1000994;
COBLYN					= 2102125;

-- Key items
OMNOMITE				= 11000406;	-- the lure Lefchild hands you
BRIGHT_EYE				= 11000405;	-- the rare stone

-- Counters
COUNTER_COBLYNS			= 0;
COBLYNS_MAX				= 30;		-- the thirtieth always yields it
EYE_CHANCE				= 6;		-- otherwise one kill in six, after the third

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
		quest:SetENpc(LEFCHILD, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(LEFCHILD);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(LEFCHILD, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();

	if (classId == LEFCHILD and sequence == SEQ_ACCEPT) then
		-- the Flames' demand, and the two stones
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventCLIFTONStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
			player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(OMNOMITE, 1, 1);
		end
	elseif (classId == LEFCHILD and sequence == SEQ_000) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_000");
	elseif (classId == LEFCHILD and sequence == SEQ_010) then
		-- not a mutation after all: the eye of an enraged coblyn
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010");
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(BRIGHT_EYE, 1);
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(OMNOMITE, 1);
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
	if (quest:GetSequence() ~= SEQ_000 or bnpc ~= COBLYN) then
		return;
	end
	-- the counter reads back stale within this hook: count this kill by hand
	local killed = quest:GetData():GetCounter(COUNTER_COBLYNS) + 1;
	quest:GetData():IncCounter(COUNTER_COBLYNS);
	if (killed >= COBLYNS_MAX or (killed > 3 and math.random(EYE_CHANCE) == 1)) then
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(BRIGHT_EYE, 1, 1);
		attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
		quest:StartSequence(SEQ_010);
	end
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
