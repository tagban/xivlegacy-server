require ("global")
require ("quest")

--[[

Quest Script

Name: 	Toll of the Warden
Code: 	Man300
Id: 	110015
Prereq: Man206 complete. Level 30.

Minfilia sends you to the Ashcrown Consortium, the crystal traders in
Gridania's Peasants Ward (zone 161). Its Interlocutors, Shanga Meshanga and
Troxia, send you to Camp Drybone, where your Path companion has found the
Amalj'aa excavation site in a mesa west of the camp. In the cave the
Consortium's Nananoby is failing to talk the Amalj'aa and Ixal out of
summoning their primals; you stop the summoning by force (a duty in place,
SimpleContentMan30001), an Ascian scatters the tribes, and you bring the
crystals they left behind back to Hedyn for your reward.

The client script (x9wgjj) names the events; seed 120 holds the cast and
triggers. Its journal goes on to a Silvertear Falls errand the 1.23b
scenes don't play: Hedyn pays you in pE60 and the story moves on.

]]

-- Sequence Numbers
SEQ_010	= 10;	-- Go to the Ashcrown Consortium in Gridania's Peasants Ward.
SEQ_015	= 15;	-- Speak with Hedyn at the Consortium's front door.
SEQ_020	= 20;	-- Travel to Camp Drybone in Eastern Thanalan.
SEQ_030	= 30;	-- Find the Ashcrown party in the mesa; speak with Nananoby.
SEQ_050	= 50;	-- Return to the Consortium with the crystals.

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
NANANOBY				= 1001050;

-- Doors and triggers
ULDAH_MARKET_ENTRANCE	= 1090265;
GRIDANIA_MARKET_ENTRANCE = 1090264;
WAKING_SANDS_EXIT		= 1090160;
CONSORTIUM_EXIT			= 1090295;
DRYBONE_TRIGGER			= 1090294;

-- Places
WAKING_SANDS_DOOR		= {-205.25, 0, -160, 1.55};
WAKING_SANDS_AREA		= 3;	-- Minfilia and the staff
ULDAH_MARKET_OUTSIDE	= {175, -216.52, 190, 30.5, 2.32};
CONSORTIUM_DOOR			= {161, -36.0, 0.0, -2.0, 1.57};
GRIDANIA_MARKET_OUTSIDE	= {206, -180.0, 22.0, -1408.0, 1.5};
DRYBONE_OUTSIDE			= {171, 1251.7, 264.0, -533.9, 3.14};
MESA_MOUTH				= {171, 1052.0, 252.4, -278.5, -1.57};

-- Quest Markers
MRKR_GRIDANIA_ENTRANCE	= 11001501;
MRKR_HEDYN				= 11001502;
MRKR_CAMP_DRYBONE		= 11001503;
MRKR_NANANOBY			= 11001506;

STAFF = {TATARU, SERANELIEN, SAHJA_ZHWAN, NENEKANI, GODFREY, FENANA, NONORU};

function onStart(player, quest)
	quest:StartSequence(SEQ_010);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(MINFILIA, QFLAG_TALK);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(TATARU, QFLAG_TALK);
	elseif (sequence == SEQ_015) then
		quest:SetENpc(HEDYN, QFLAG_TALK);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(DRYBONE_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_030) then
		quest:SetENpc(NANANOBY, QFLAG_TALK);
	elseif (sequence == SEQ_050) then
		quest:SetENpc(HEDYN, QFLAG_REWARD);
	end

	-- The Waking Sands: its staff's chatter, and the way in and out.
	if (sequence == SEQ_ACCEPT or sequence == SEQ_010) then
		for _, npc in ipairs(STAFF) do
			if (not (npc == TATARU and sequence == SEQ_010)) then
				quest:SetENpc(npc);
			end
		end
		quest:SetENpc(ULDAH_MARKET_ENTRANCE, QFLAG_PUSH, false, true);
		quest:SetENpc(WAKING_SANDS_EXIT, QFLAG_NONE, false, true);
	end

	-- The Consortium: in through Gridania's market entrance, out its door.
	if (sequence == SEQ_010 or sequence == SEQ_015 or sequence == SEQ_050) then
		quest:SetENpc(GRIDANIA_MARKET_ENTRANCE, QFLAG_PUSH, false, true);
	end
	if (sequence >= SEQ_015) then
		quest:SetENpc(CONSORTIUM_EXIT, QFLAG_NONE, false, true);
		if (sequence ~= SEQ_015 and sequence ~= SEQ_050) then
			quest:SetENpc(HEDYN);
		end
		quest:SetENpc(SHANGA_MESHANGA);
		quest:SetENpc(TROXIA);
	end
end

function companionArgs(player)
	return player:GetSNpcNickname(), player:GetSNpcSkin(), player:GetSNpcPersonality(), player:GetSNpcCoordinate(), player:GetInitialTown();
end

function warpTo(player, spot)
	GetWorldManager():DoZoneChange(player, spot[1], nil, 0, 15, spot[2], spot[3], spot[4], spot[5]);
end

function onTalk(player, quest, npc)
	local sequence = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (sequence == SEQ_ACCEPT and classId == MINFILIA) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "pEStart", player:GetSNpcNickname(), player:GetSNpcSkin());
		if (accepted == 1) then
			-- Minfilia's briefing; it fades in after a warp
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000");
			player:EndEvent();
			player:AcceptQuest(quest, true);
			GetWorldManager():DoZoneChange(player, 181, "PrivateAreaMasterPast", WAKING_SANDS_AREA, 15, -142.75, 1, -160, -1.6);
			return;
		end
	elseif (sequence == SEQ_010 and classId == TATARU) then
		-- directions to the Consortium
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010_2");
	elseif (sequence == SEQ_015 and classId == HEDYN) then
		-- the Interlocutors, the primals, and Camp Drybone; it fades in after a warp
		callClientFunction(player, "delegateEvent", player, quest, "pE20", companionArgs(player));
		player:EndEvent();
		quest:StartSequence(SEQ_020);
		warpTo(player, CONSORTIUM_DOOR);
		return;
	elseif (sequence == SEQ_030 and classId == NANANOBY) then
		-- the failing negotiation; then the summoning must be stopped
		callClientFunction(player, "delegateEvent", player, quest, "pE40", companionArgs(player));
		startMan300Content(player, quest);
		return;
	elseif (sequence == SEQ_050 and classId == HEDYN) then
		-- the crystals, the Paragons, and the reward; it fades in after a warp
		callClientFunction(player, "delegateEvent", player, quest, "pE60", companionArgs(player));
		-- Completion reward from the client's quest reward sheet: 50 EXP + 90,000 gil.
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 50, 1, 1, 2);
		player:AddExp(50, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddGil(90000);
		player:EndEvent();
		player:CompleteQuest(quest);
		warpTo(player, GRIDANIA_MARKET_OUTSIDE);
		return;
	elseif (classId == SHANGA_MESHANGA) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_2", companionArgs(player));
	elseif (classId == TROXIA) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_3", companionArgs(player));
	elseif (classId == HEDYN) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent022_1", companionArgs(player));
	else
		-- the Waking Sands staff: before the briefing, then after it
		staffChatter(player, quest, classId, sequence == SEQ_ACCEPT and "processEvent000_" or "processEvent005_");
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function staffChatter(player, quest, classId, prefix)
	for i, npc in ipairs(STAFF) do
		if (classId == npc) then
			callClientFunction(player, "delegateEvent", player, quest, prefix .. (i + 1), player:GetSNpcNickname(), player:GetSNpcSkin());
			return;
		end
	end
end

function onPush(player, quest, npc)
	local sequence = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (classId == ULDAH_MARKET_ENTRANCE) then
		player:EndEvent();
		GetWorldManager():DoZoneChange(player, 181, "PrivateAreaMasterPast", WAKING_SANDS_AREA, 15,
			WAKING_SANDS_DOOR[1], WAKING_SANDS_DOOR[2], WAKING_SANDS_DOOR[3], WAKING_SANDS_DOOR[4]);
		return;
	elseif (classId == WAKING_SANDS_EXIT) then
		player:EndEvent();
		warpTo(player, ULDAH_MARKET_OUTSIDE);
		return;
	elseif (classId == GRIDANIA_MARKET_ENTRANCE) then
		if (sequence == SEQ_010) then
			-- the sylphs flee the hall; it fades in after a warp
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010", companionArgs(player));
			quest:StartSequence(SEQ_015);
		end
		player:EndEvent();
		warpTo(player, CONSORTIUM_DOOR);
		return;
	elseif (classId == CONSORTIUM_EXIT) then
		player:EndEvent();
		warpTo(player, GRIDANIA_MARKET_OUTSIDE);
		return;
	elseif (classId == DRYBONE_TRIGGER and sequence == SEQ_020) then
		-- your companion has found the excavation site; it fades in after a warp
		callClientFunction(player, "delegateEvent", player, quest, "pE30", companionArgs(player));
		player:EndEvent();
		quest:StartSequence(SEQ_030);
		warpTo(player, DRYBONE_OUTSIDE);
		return;
	end

	player:EndEvent();
end

-- The summoning in the cave, a duty entered in place (spawnType 0x16): the
-- scenes are shot on Eastern Thanalan's own map. Its director
-- (QuestDirectorMan30001) plays the Ascian once the tribes are beaten.
function startMan300Content(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Man30001", "SimpleContentMan30001", "Quest/QuestDirectorMan30001");
	if (contentArea == nil) then
		player:EndEvent();
		return;
	end
	local director = contentArea:GetContentDirector();
	player:AddDirector(director);
	director:StartDirector(false);
	player:KickEvent(director, "noticeEvent", true);
	player:SetLoginDirector(director);
	player:EndEvent();
	GetWorldManager():DoZoneChangeContent(player, contentArea,
		player.positionX, player.positionY, player.positionZ, player.rotation, 0x16);
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0, player:GetSNpcNickname();
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:getSequence();

	if (sequence == SEQ_010) then
		return MRKR_GRIDANIA_ENTRANCE;
	elseif (sequence == SEQ_015 or sequence == SEQ_050) then
		return MRKR_HEDYN;
	elseif (sequence == SEQ_020) then
		return MRKR_CAMP_DRYBONE;
	elseif (sequence == SEQ_030) then
		return MRKR_NANANOBY;
	end
end
