require ("global")
require ("quest")

--[[

Quest Script

Name: 	Eternal Recurrence
Code: 	Gcg301
Id: 	111617
Prereq: Level 25, a sworn member of the Order of the Twin Adder (company_gate in quest_offers.rs).

The Twin Adder needs leather armor, and Dyrstbrod of the Leatherworkers'
Guild would rather mend the scraps the old battlefield on Fallgourd Lake
still holds than tan fresh hides. Hungry dreadwolves prowl there, so he
hands you hypnotic scales to draw them off. Back in the guild he works
the salvaged leather into armor anew.

The client script (gcg301) names the events; seed 162 places the
dreadwolves on the south shore of Fallgourd Lake.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Recover leather scraps by Fallgourd Lake (slay the dreadwolves there).
SEQ_010	= 10;	-- Bring the scraps to Dyrstbrod.

-- Quest Actors
DYRSTBROD				= 1001079;
HUNGRY_DREADWOLF		= 2201412;

-- Key items
LEATHER_SCRAP			= 11000401;
HYPNOTIC_SCALES			= 11000402;	-- the lure Dyrstbrod hands you

-- Counters
COUNTER_WOLVES			= 0;
WOLVES_NEEDED			= 5;

-- Rewards (the client's reward sheet row: EXP tier 7 in slot 1, seals in slot 5)
REWARD_EXP				= 1541;
REWARD_SEALS			= 300;
COMPANY					= 2;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(DYRSTBROD, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(DYRSTBROD);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(DYRSTBROD, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();

	if (classId == DYRSTBROD and sequence == SEQ_ACCEPT) then
		-- the battlefield's leather, and the wolves that guard it
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventDYRSTBRODStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
			player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(HYPNOTIC_SCALES, 1, 1);
		end
	elseif (classId == DYRSTBROD and sequence == SEQ_000) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_000");
	elseif (classId == DYRSTBROD and sequence == SEQ_010) then
		-- old leather made new
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010");
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(LEATHER_SCRAP, 1);
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(HYPNOTIC_SCALES, 1);
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
	if (quest:GetSequence() ~= SEQ_000 or bnpc ~= HUNGRY_DREADWOLF) then
		return;
	end
	-- the counter reads back stale within this hook: count this kill by hand
	local killed = quest:GetData():GetCounter(COUNTER_WOLVES) + 1;
	quest:GetData():IncCounter(COUNTER_WOLVES);
	if (killed >= WOLVES_NEEDED) then
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(LEATHER_SCRAP, 1, 1);
		attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
		quest:StartSequence(SEQ_010);
	end
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
