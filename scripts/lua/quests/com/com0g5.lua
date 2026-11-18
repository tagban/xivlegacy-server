require ("global")
require ("quest")

--[[

Quest Script

Name: 	Their Finest Hour
Code: 	Com0g5
Id: 	111605
Prereq: Com0g4 complete (a Twin Adder recruit).

The Order of the Twin Adder holds a ceremony at Mih Khetto's Amphitheatre,
where Elder Seedseer Kan-E-Senna will speak. Fulke gives a recruit an
invitation and sends them to it. After the address, Thancred, who advised
the Elder Seedseer to reform the Order, gives you an Earthbreaker and asks
you to meet him at the Rootslake, east of Camp Tranquil. There Urianger
reads the sixth verse of the Divine Chronicles and sends you to hear the
other two nations' leaders.

The client script (com0g5) names the events; seed 129 holds the cast. The
amphitheatre trigger is Man2g0's (seed 114). The ceremony cutscene (com0g610)
ends on a warp, so the player is set down on the amphitheatre's benches.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Attend the ceremony at Mih Khetto's Amphitheatre.
SEQ_010	= 10;	-- Speak with Thancred at the amphitheatre.
SEQ_020	= 20;	-- Meet Thancred at the Rootslake.
SEQ_030	= 30;	-- Speak with Urianger at the Rootslake.

-- Quest Actors
FULKE					= 1500200;
THANCRED				= 1000185;
URIANGER				= 1500204;
STALWART_WAILER			= 1000851;	-- "I will fight for Gridania"
SERPENT_CAPTAIN			= 1001896;	-- "all looked to be in high spirits"
WISE_CONJURER			= 1000743;	-- "did you see the elemental?"
FLUSTERED_MOTHER		= 1000422;	-- "I lost track of young Sansa"
EXCITED_CHILD			= 1000424;	-- "what's taking Zuzupoja so long?"

-- Triggers
AMPHITHEATRE			= 1090279;

-- Key Items
CEREMONY_INVITATION		= 11000271;
EARTHBREAKER			= 11000272;

-- Places
AMPHITHEATRE_SEATS		= {206, -96.9, 10.6, -1630.8, -3.10};
GRIDANIA				= 206;
SOUTH_SHROUD			= 154;

-- Rewards (the client's reward sheet row: an EXP tier in slot 1, seals in slot 5)
REWARD_EXP				= 1541;
REWARD_SEALS			= 300;
COMPANY					= 2;

-- The crowd after the ceremony: each bystander's talk.
CROWD = {
	[STALWART_WAILER]	= "processEvent010_1",
	[SERPENT_CAPTAIN]	= "processEvent010_2",
	[WISE_CONJURER]		= "processEvent010_3",
	[FLUSTERED_MOTHER]	= "processEvent010_4",
	[EXCITED_CHILD]		= "processEvent010_5",
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(FULKE, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(AMPHITHEATRE, QFLAG_PUSH, false, true);
		quest:SetENpc(FULKE);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(THANCRED, QFLAG_TALK);
		for classId in pairs(CROWD) do
			quest:SetENpc(classId);
		end
	elseif (sequence == SEQ_020) then
		quest:SetENpc(THANCRED, QFLAG_TALK);
		for classId in pairs(CROWD) do
			quest:SetENpc(classId);
		end
	elseif (sequence == SEQ_030) then
		quest:SetENpc(URIANGER, QFLAG_REWARD);
		quest:SetENpc(THANCRED);
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:getSequence();
	local classId = npc:GetActorClassId();
	local zone = player:GetZoneID();

	if (sequence == SEQ_ACCEPT and classId == FULKE) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventFulkeStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
			player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(CEREMONY_INVITATION, 1, 1);
		end
	elseif (sequence == SEQ_000 and classId == FULKE) then
		callClientFunction(player, "delegateEvent", player, quest, "followEvent005");
	elseif (sequence == SEQ_010 and classId == THANCRED and zone == GRIDANIA) then
		-- the Elder Seedseer's words, the Earthbreaker, and the Rootslake
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(EARTHBREAKER, 1, 1);
		callClientFunction(player, "delegateEvent", player, quest, "processEvent011");
		callClientFunction(player, "delegateEvent", player, quest, "processEvent012");
		quest:StartSequence(SEQ_020);
	elseif ((sequence == SEQ_010 or sequence == SEQ_020) and CROWD[classId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, CROWD[classId]);
	elseif (sequence == SEQ_020 and classId == THANCRED and zone == SOUTH_SHROUD) then
		-- the monster you felled, the prophecies, and the misinformation
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020", 0);
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020", 1);
		quest:StartSequence(SEQ_030);
	elseif (sequence == SEQ_030 and classId == THANCRED and zone == SOUTH_SHROUD) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020", 2);
	elseif (sequence == SEQ_030 and classId == URIANGER) then
		-- the sixth verse, the men of stone, and the road to the other nations
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030", 0);
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
	if (npc:GetActorClassId() == AMPHITHEATRE and quest:getSequence() == SEQ_000) then
		-- Kan-E-Senna's address; the cutscene ends on a warp
		callClientFunction(player, "delegateEvent", player, quest, "processEvent005");
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(CEREMONY_INVITATION, 1);
		quest:StartSequence(SEQ_010);
		player:EndEvent();
		GetWorldManager():DoZoneChange(player, AMPHITHEATRE_SEATS[1], nil, 0, 15,
			AMPHITHEATRE_SEATS[2], AMPHITHEATRE_SEATS[3], AMPHITHEATRE_SEATS[4], AMPHITHEATRE_SEATS[5]);
		return;
	end
	player:EndEvent();
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
