require ("global")
require ("quest")

--[[

Quest Script

Name: 	Kobold and the Beautiful
Code: 	Gcl304
Id: 	111420
Prereq: Level 45, a sworn member of the Maelstrom (company_gate in quest_offers.rs).

Kobolds have been stealing shipments of sthalite from ships in Galadion Bay,
and Lilina of Mealvaan's Gate fears they mean to make war with it. She sends
you to the U'Ghamaro Mines by way of Camp Iron Lake, where Chief Storm
Sergeant Kurtz Nolan hands you a vial of coblyn choler: it turns green on
metal that holds sthalite. Inside the mines you test the kobolds' great metal
works, and none of them turns the liquid green. Nolan fears the ore lies in
chambers deeper still, and pays you in Mealvaan's Gate's stead.

The client script (gcl304) names the events; seed 160 holds Nolan, the mine
mouth (which takes you into the mines while the quest needs you there; no
other way in exists yet), the way back out, and the three metal works.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Report to Chief Storm Sergeant Nolan at Camp Iron Lake.
SEQ_005	= 5;	-- Test the metal in the U'Ghamaro Mines.
SEQ_015	= 15;	-- Report to Nolan.

-- Quest Actors
LILINA					= 1000178;
NOLAN					= 1001697;	-- Chief Storm Sergeant Kurtz Nolan

-- Triggers
MINE_MOUTH				= 1090347;	-- Upper La Noscea, into the mines
MINE_EXIT				= 1090348;	-- the mines, back out
METAL_WORKS = {							-- each tested once, by flag
	[1090349] = 0,	-- the Central Furnaces door
	[1090350] = 1,	-- the door under the Burner Loft
	[1090351] = 2,	-- the door of Dome 2610
};
METAL_TOTAL				= 3;

-- Places
MINES_INSIDE			= {137, 82.0, -11.7, -2953.0, 0.0};	-- facing the furnaces door
MINE_OUTSIDE			= {135, 97.1, 64.4, -2702.8, 2.6};

-- Key items
COBLYN_CHOLER			= 11000408;	-- the coblyn humours Nolan hands you

-- Counters
COUNTER_TESTED			= 0;

-- Rewards (the client's reward sheet row: EXP tier 5 in slot 1, seals in slot 5)
REWARD_EXP				= 1103;
REWARD_SEALS			= 700;
COMPANY					= 1;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(LILINA, QFLAG_TALK);
		return;
	end

	quest:SetENpc(LILINA);
	quest:SetENpc(NOLAN, (sequence == SEQ_000 and QFLAG_TALK) or (sequence == SEQ_015 and QFLAG_REWARD) or QFLAG_NONE);
	if (sequence == SEQ_005) then
		quest:SetENpc(MINE_MOUTH, QFLAG_PUSH, false, true);
		quest:SetENpc(MINE_EXIT, QFLAG_PUSH, false, true);
		for metal in pairs(METAL_WORKS) do
			quest:SetENpc(metal, QFLAG_PUSH, false, true);
		end
	elseif (sequence == SEQ_015) then
		-- still a way out for whoever finishes inside
		quest:SetENpc(MINE_EXIT, QFLAG_PUSH, false, true);
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();

	if (classId == LILINA and sequence == SEQ_ACCEPT) then
		-- the stolen sthalite, and the kobolds of O'Ghomoro
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventLilinaStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (classId == LILINA) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_000");
	elseif (classId == NOLAN and sequence == SEQ_000) then
		-- cobalt iron, and the coblyn choler
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_005");
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(COBLYN_CHOLER, 1, 1);
		quest:StartSequence(SEQ_005);
	elseif (classId == NOLAN and sequence == SEQ_005) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_005_01");
	elseif (classId == NOLAN and sequence == SEQ_015) then
		-- cauldron-shaped buildings, and no sthalite in any of them
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_015");
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(COBLYN_CHOLER, 1);
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
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();

	if (classId == MINE_MOUTH and sequence == SEQ_005) then
		player:EndEvent();
		GetWorldManager():DoZoneChange(player, MINES_INSIDE[1], nil, 0, 15,
			MINES_INSIDE[2], MINES_INSIDE[3], MINES_INSIDE[4], MINES_INSIDE[5]);
		return;
	elseif (classId == MINE_EXIT) then
		player:EndEvent();
		GetWorldManager():DoZoneChange(player, MINE_OUTSIDE[1], nil, 0, 15,
			MINE_OUTSIDE[2], MINE_OUTSIDE[3], MINE_OUTSIDE[4], MINE_OUTSIDE[5]);
		return;
	elseif (METAL_WORKS[classId] ~= nil and sequence == SEQ_005) then
		local flag = METAL_WORKS[classId];
		if (quest:GetData():GetFlag(flag)) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_010_02");
		elseif (callClientFunction(player, "delegateEvent", player, quest, "processEvent_010") == 1) then
			quest:GetData():SetFlag(flag);
			-- the counter reads back stale within this hook: count this one by hand
			local tested = quest:GetData():GetCounter(COUNTER_TESTED) + 1;
			quest:GetData():IncCounter(COUNTER_TESTED);
			-- nothing happens (tested/total)
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_010_01", tested, METAL_TOTAL);
			if (tested >= METAL_TOTAL) then
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
