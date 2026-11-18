require ("global")
require ("quest")

--[[

Quest Script

Name: 	Forever Taken
Code: 	Man304
Id: 	110016
Prereq: Man300 complete. Level 34.

A sylph calls you on the Consortium's linkpearl: help is needed at Ashcrown.
There Hedyn and the sylphs ask you to bring the Ixal and the Amalj'aa to
the table with a gift both tribes prize, Unaspected Crystals, which only
Mor Dhona's soil can make. You bury five crystals of one element at five
warm spots around a pond where the Black Shroud road enters Mor Dhona, and
bring the drained crystals back to Hedyn. Then Minfilia calls everyone to
the Waking Sands: the Empire has been showering the free cities with
imperial linkpearls, and when your companion presses her, she resolves to
open talks with the beast tribes herself.

The client script (x9wgjf) names the events; seed 168 holds the burial
spots. In 1.0 a buried crystal had to be left a few minutes and dug up
again; here it is drained as soon as it is buried. The element asked for
differed from player to player; here it follows the character's id. Your
Path companion has no actor in the Waking Sands, so the last scene plays
when you speak with Minfilia again. Minfilia's office doors only work
during Man206, so this quest opens them while it needs her.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Bury five crystals around the pond in Mor Dhona.
SEQ_010	= 10;	-- Bring the Unaspected Crystals to Hedyn at Ashcrown.
SEQ_020	= 20;	-- Go to the Waking Sands and hear Minfilia.
SEQ_030	= 30;	-- Speak with your companion (Minfilia) at the Waking Sands.

-- Quest Actors
MINFILIA				= 1000843;
TATARU					= 1001046;
SAHJA_ZHWAN				= 1001373;
NENEKANI				= 1001374;
GODFREY					= 1001375;
FENANA					= 1001376;
NONORU					= 1001377;
SERANELIEN				= 1001378;

HEDYN					= 1001047;
SHANGA_MESHANGA			= 1001048;
TROXIA					= 1001049;

STAFF = {TATARU, SERANELIEN, SAHJA_ZHWAN, NENEKANI, GODFREY, FENANA, NONORU};

-- Doors and triggers
ULDAH_MARKET_ENTRANCE	= 1090265;
GRIDANIA_MARKET_ENTRANCE = 1090264;
WAKING_SANDS_EXIT		= 1090160;
OFFICE_DOOR_IN			= 1090161;	-- Minfilia's office, from the hall
OFFICE_DOOR_OUT			= 1090162;
CONSORTIUM_EXIT			= 1090295;
BURIAL_SPOTS = {						-- each takes one crystal, by flag
	[1090358] = 0,	-- the north valley wall
	[1090359] = 1,	-- the east valley wall, by the Shroud road
	[1090360] = 2,	-- the pond's east bank
	[1090361] = 3,	-- the pond's west bank
	[1090362] = 4,	-- north of the pond
};
BURIALS_NEEDED			= 5;

-- Quest Markers
MRKR_HEDYN				= 11001603;
MRKR_ULDAH_ENTRANCE		= 11001605;
MRKR_BURIAL				= {11001610, 11001611, 11001607, 11001608, 11001609}; -- by burial flag

-- Places
WAKING_SANDS_DOOR		= {-205.25, 0, -160, 1.55};
WAKING_SANDS_AREA		= 3;	-- Minfilia and the staff
WAKING_SANDS_OFFICE		= {-126.2, 1.2, -160, 1.6};	-- inside Minfilia's door
WAKING_SANDS_HALL		= {-142.75, 1, -160, -1.6};	-- outside it
ULDAH_MARKET_OUTSIDE	= {175, -216.52, 190, 30.5, 2.32};
CONSORTIUM_DOOR			= {161, -36.0, 0.0, -2.0, 1.57};
GRIDANIA_MARKET_OUTSIDE	= {206, -180.0, 22.0, -1408.0, 1.5};

-- Items
FIRE_CRYSTAL			= 1000009;	-- the six elemental crystals run 1000009-1000014, fire first
UNASPECTED_CRYSTAL		= 11000096;	-- key item
ELEMENT_NAMES			= {"fire", "ice", "wind", "earth", "lightning", "water"};

-- Counters
COUNTER_BURIED			= 0;

-- Rewards
REWARD_GIL				= 102000;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(HEDYN, QFLAG_TALK);
	else
		quest:SetENpc(HEDYN, (sequence == SEQ_010 and QFLAG_REWARD) or QFLAG_NONE);
	end

	-- Ashcrown: Hedyn's people, and the way in and out.
	quest:SetENpc(SHANGA_MESHANGA);
	quest:SetENpc(TROXIA);
	quest:SetENpc(GRIDANIA_MARKET_ENTRANCE, QFLAG_PUSH, false, true);
	quest:SetENpc(CONSORTIUM_EXIT, QFLAG_NONE, false, true);

	if (sequence == SEQ_000) then
		for spot in pairs(BURIAL_SPOTS) do
			quest:SetENpc(spot, QFLAG_PUSH, false, true);
		end
	end

	-- The Waking Sands: Minfilia's speech and its aftermath.
	if (sequence == SEQ_020 or sequence == SEQ_030) then
		quest:SetENpc(MINFILIA, QFLAG_TALK);
		for _, npc in ipairs(STAFF) do
			quest:SetENpc(npc);
		end
		quest:SetENpc(ULDAH_MARKET_ENTRANCE, QFLAG_PUSH, false, true);
		quest:SetENpc(WAKING_SANDS_EXIT, QFLAG_NONE, false, true);
		quest:SetENpc(OFFICE_DOOR_IN, QFLAG_NONE, false, true);
		quest:SetENpc(OFFICE_DOOR_OUT, QFLAG_NONE, false, true);
	end
end

function companionArgs(player)
	return player:GetSNpcNickname(), player:GetSNpcSkin(), player:GetSNpcPersonality(), player:GetSNpcCoordinate(), player:GetInitialTown();
end

function warpTo(player, spot)
	GetWorldManager():DoZoneChange(player, spot[1], nil, 0, 15, spot[2], spot[3], spot[4], spot[5]);
end

function warpToWakingSands(player, spot)
	GetWorldManager():DoZoneChange(player, 181, "PrivateAreaMasterPast", WAKING_SANDS_AREA, 15, spot[1], spot[2], spot[3], spot[4]);
end

-- The element the sylphs asked this adventurer to bury: 1 fire, 2 ice, 3
-- wind, 4 earth, 5 lightning, 6 water (the order of the crystal items, and
-- of the dialogue's element switch).
function burialElement(player)
	return 1 + (player.actorId % 6);
end

function onTalk(player, quest, npc)
	local sequence = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (sequence == SEQ_ACCEPT and classId == HEDYN) then
		-- the sylphs' plea for Unaspected Crystals
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "pES", companionArgs(player));
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (sequence == SEQ_010 and classId == HEDYN) then
		-- the sylphs receive the crystals and speak of the Paragons
		callClientFunction(player, "delegateEvent", player, quest, "pE10", companionArgs(player));
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(UNASPECTED_CRYSTAL, 1);
		quest:StartSequence(SEQ_020);
	elseif (classId == HEDYN) then
		callClientFunction(player, "delegateEvent", player, quest, sequence == SEQ_000 and "processEvent001_2" or "processEvent005_1");
	elseif (classId == SHANGA_MESHANGA) then
		-- where Unaspected Crystals come from
		callClientFunction(player, "delegateEvent", player, quest, sequence == SEQ_ACCEPT and "processEvent000_10" or "processEvent001_3", burialElement(player));
	elseif (classId == TROXIA) then
		-- bury crystals at the warm spots of Mor Dhona
		callClientFunction(player, "delegateEvent", player, quest, sequence == SEQ_ACCEPT and "processEvent000_12" or "processEvent001_6", burialElement(player));
	elseif (sequence == SEQ_020 and classId == MINFILIA) then
		-- the imperial linkpearls; it fades in after a warp
		callClientFunction(player, "delegateEvent", player, quest, "pE20", companionArgs(player));
		player:EndEvent();
		quest:StartSequence(SEQ_030);
		warpToWakingSands(player, WAKING_SANDS_OFFICE);
		return;
	elseif (sequence == SEQ_030 and classId == MINFILIA) then
		-- your companion presses Minfilia; it fades in after a warp
		callClientFunction(player, "delegateEvent", player, quest, "pE30", companionArgs(player));
		-- Completion reward from the client's quest reward sheet: 50 EXP + REWARD_GIL.
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 50, 1, 1, 2);
		player:AddExp(50, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddGil(REWARD_GIL);
		player:EndEvent();
		player:CompleteQuest(quest);
		warpToWakingSands(player, WAKING_SANDS_OFFICE);
		return;
	else
		-- the Waking Sands staff before the speech
		for i, staff in ipairs(STAFF) do
			if (classId == staff) then
				callClientFunction(player, "delegateEvent", player, quest, "processEvent010_" .. (i + 1));
			end
		end
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onPush(player, quest, npc)
	local sequence = quest:getSequence();
	local classId = npc:GetActorClassId();
	local flag = BURIAL_SPOTS[classId];

	if (flag ~= nil and sequence == SEQ_000) then
		if (not quest:GetData():GetFlag(flag)) then
			buryCrystal(player, quest, flag);
		end
	elseif (classId == ULDAH_MARKET_ENTRANCE) then
		player:EndEvent();
		warpToWakingSands(player, WAKING_SANDS_DOOR);
		return;
	elseif (classId == OFFICE_DOOR_IN) then
		player:EndEvent();
		GetWorldManager():WarpToPosition(player, WAKING_SANDS_OFFICE[1], WAKING_SANDS_OFFICE[2], WAKING_SANDS_OFFICE[3], WAKING_SANDS_OFFICE[4]);
		return;
	elseif (classId == OFFICE_DOOR_OUT) then
		player:EndEvent();
		GetWorldManager():WarpToPosition(player, WAKING_SANDS_HALL[1], WAKING_SANDS_HALL[2], WAKING_SANDS_HALL[3], WAKING_SANDS_HALL[4]);
		return;
	elseif (classId == WAKING_SANDS_EXIT) then
		player:EndEvent();
		warpTo(player, ULDAH_MARKET_OUTSIDE);
		return;
	elseif (classId == GRIDANIA_MARKET_ENTRANCE) then
		player:EndEvent();
		warpTo(player, CONSORTIUM_DOOR);
		return;
	elseif (classId == CONSORTIUM_EXIT) then
		player:EndEvent();
		warpTo(player, GRIDANIA_MARKET_OUTSIDE);
		return;
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function buryCrystal(player, quest, flag)
	local element = burialElement(player);
	local crystal = FIRE_CRYSTAL + element - 1;
	local currency = player:GetItemPackage(INVENTORY_CURRENCY);
	if (not currency:HasItem(crystal, 1)) then
		-- The client's own line for this (processEvent000_22) goes through
		-- worldMaster:tell, which 1.23b no longer has; say it from here.
		player:SendMessage(MESSAGE_TYPE_SYSTEM, "", string.format("However, you do not possess any %s crystals to bury.", ELEMENT_NAMES[element]));
		return;
	end
	if (callClientFunction(player, "delegateEvent", player, quest, "processEvent000_20") ~= 1) then
		return;
	end
	currency:RemoveItem(crystal, 1);
	quest:GetData():SetFlag(flag);
	-- the counter reads back stale within this hook: count this one by hand
	local buried = quest:GetData():GetCounter(COUNTER_BURIED) + 1;
	quest:GetData():IncCounter(COUNTER_BURIED);
	if (buried >= BURIALS_NEEDED) then
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(UNASPECTED_CRYSTAL, 1, 1);
		attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
		quest:StartSequence(SEQ_010);
	end
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0, player:GetSNpcNickname();
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:getSequence();

	if (sequence == SEQ_000) then
		local markers = {};
		for spot, flag in pairs(BURIAL_SPOTS) do
			if (not quest:GetData():GetFlag(flag)) then
				table.insert(markers, MRKR_BURIAL[flag + 1]);
			end
		end
		return unpack(markers);
	elseif (sequence == SEQ_010) then
		return MRKR_HEDYN;
	else
		return MRKR_ULDAH_ENTRANCE;
	end
end
