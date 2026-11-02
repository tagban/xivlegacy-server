require ("global")
require ("quest")

--[[

Quest Script

Name: 	Gone with the Wind
Code: 	Gcg304
Id: 	111620
Prereq: Level 45, a sworn member of the Order of the Twin Adder (company_gate in quest_offers.rs).

The Ixal felled trees in the Twelveswood on a day of gales, when their
balloons should never have flown. Alaire of the Gods' Quiver sends you to
Camp Dragonhead, which keeps watch over the Ixali stronghold of Natalan.
Chief Serpent Sergeant Liflin Gulin saw a balloon fly against the wind and
sends you into Natalan for three pieces of evidence. Among the leather panel
and kite plume is an Eye of Garuda: an airstone blessed by Garuda herself,
strong enough to push a balloon upwind.

The client script (gcg304) names the events; seed 165 holds Liflin Gulin and
the three places in Natalan's outer works.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Ask the soldiers at Camp Dragonhead.
SEQ_005	= 5;	-- Find three pieces of the balloon in Natalan.
SEQ_015	= 15;	-- Report to Liflin Gulin.

-- Quest Actors
ALAIRE					= 1000831;
LIFLIN_GULIN			= 1001698;	-- Chief Serpent Sergeant Liflin Gulin

-- Triggers: each place in Natalan, its flag and the part found there
BALLOON_PARTS = {
	[1090352] = {0, 11000409},	-- Leather Balloon Panel, by the supply crates
	[1090353] = {1, 11000410},	-- Treated Kite Plume, west of the barricade
	[1090354] = {2, 11000411},	-- Eye of Garuda, on the slope south of it
};
PARTS_TOTAL				= 3;

-- Counters
COUNTER_PARTS			= 0;

-- Rewards (the client's reward sheet row: EXP tier 5 in slot 1, seals in slot 5)
REWARD_EXP				= 1103;
REWARD_SEALS			= 700;
COMPANY					= 2;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ALAIRE, QFLAG_TALK);
		return;
	end

	quest:SetENpc(ALAIRE);
	quest:SetENpc(LIFLIN_GULIN, (sequence == SEQ_000 and QFLAG_TALK) or (sequence == SEQ_015 and QFLAG_REWARD) or QFLAG_NONE);
	if (sequence == SEQ_005) then
		for part in pairs(BALLOON_PARTS) do
			quest:SetENpc(part, QFLAG_PUSH, false, true);
		end
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();

	if (classId == ALAIRE and sequence == SEQ_ACCEPT) then
		-- the Ixal flew in a gale
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventALAIREStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (classId == ALAIRE) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_000");
	elseif (classId == LIFLIN_GULIN and sequence == SEQ_000) then
		-- a balloon flying against the wind
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_005");
		quest:StartSequence(SEQ_005);
	elseif (classId == LIFLIN_GULIN and sequence == SEQ_005) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_005_01");
	elseif (classId == LIFLIN_GULIN and sequence == SEQ_015) then
		-- an Eye of Garuda
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_015");
		for _, part in pairs(BALLOON_PARTS) do
			player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(part[2], 1);
		end
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
	local part = BALLOON_PARTS[npc:GetActorClassId()];

	if (part ~= nil and quest:GetSequence() == SEQ_005) then
		if (quest:GetData():GetFlag(part[1])) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_010_01");
		elseif (callClientFunction(player, "delegateEvent", player, quest, "processEvent_010") == 1) then
			quest:GetData():SetFlag(part[1]);
			player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(part[2], 1, 1);
			-- the counter reads back stale within this hook: count this one by hand
			local found = quest:GetData():GetCounter(COUNTER_PARTS) + 1;
			quest:GetData():IncCounter(COUNTER_PARTS);
			if (found >= PARTS_TOTAL) then
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
