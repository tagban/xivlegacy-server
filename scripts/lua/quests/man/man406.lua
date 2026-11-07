require ("global")
require ("quest")
require ("modifiers")

--[[

Quest Script

Name: 	Futures Perfect
Code: 	Man406
Id: 	110019
Prereq: Man402 complete. Level 46.

The Ala Mhigan Resistance holds audience with Minfilia at the Waking Sands:
they mean to steal an imperial airship near Silvertear Falls and fly it
against the Empire in Ala Mhigo. Your Path companion is set on joining
them. Minfilia warns that every such attempt has failed, but your
companion leaves with the captain all the same. You follow to Camp
Revenant's Toll in Mor Dhona, where an imperial patrol is called away
before it can fight; you follow it east and fight it where it stops. At
the airship you find your companion alive and the Resistance slain by the
legatus, and the Scions save you both. After an explosion you wake in a
cave among captive children (an Echo vision), then wake again by Camp
Revenant's Toll. Back at the Waking Sands, Minfilia hears what became of
the Resistance.

The client script (x9wfjd) names the events. The audience is Waking Sands
private area 4 (area 3's cast plus the captain and four members); the
patrol fight, the airship scenes and the cave are one duty entered in
place on the road east of the camp (SimpleContentMan40601,
QuestDirectorMan40601). Your companion is in the scenes only, so pE01
(your companion in the hall) and pE52 (your companion after the cave) are
not played.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- The Resistance's audience: hear the captain out.
SEQ_010	= 10;	-- Hear every Resistance member, then answer the captain.
SEQ_015	= 15;	-- Follow your companion to Camp Revenant's Toll in Mor Dhona.
SEQ_020	= 20;	-- Follow the imperial patrol east.
SEQ_045	= 45;	-- The children's cave (an Echo vision): find the way out.
SEQ_050	= 50;	-- Report to the Waking Sands.

-- Quest Actors
MINFILIA				= 1000843;
TATARU					= 1001046;
PERCEVAINS				= 1001229;
UNA_TAYUUN				= 1001230;
SAHJA_ZHWAN				= 1001373;
NENEKANI				= 1001374;
GODFREY					= 1001375;
FENANA					= 1001376;
NONORU					= 1001377;
SERANELIEN				= 1001378;

RESISTANCE_CAPTAIN		= 1000477;
BRUTISH_MEMBER			= 1000478;
STRAPPING_MEMBER		= 1000479;
DISPASSIONATE_MEMBER	= 1000480;
UNBLOODIED_MEMBER		= 1000482;

-- The Resistance members' tales (processEvent010_n) and the quest flag set
-- once each has been heard. Speakers are matched to lines by their manner;
-- not verified against retail.
MEMBERS = {
	[STRAPPING_MEMBER]		= { event = 2, flag = 0 },	-- the Empire's breeding ground
	[DISPASSIONATE_MEMBER]	= { event = 4, flag = 1 },	-- the Resistance's watchers; the scout
	[BRUTISH_MEMBER]		= { event = 5, flag = 2 },	-- his brother, and the Wall
	[UNBLOODIED_MEMBER]		= { event = 6, flag = 3 },	-- born after the fall
};
CAPTAIN_TALE			= 1;	-- processEvent010_1: the thousands still in Ala Mhigo
CAPTAIN_WAITING			= 3;	-- processEvent010_3: the road south, while tales are unheard
MINFILIA_BEFORE			= 7;	-- processEvent010_7: hear them all first
TATARU_HALL				= 8;	-- processEvent010_8: did you listen to every tale?
MINFILIA_AFTER			= 9;	-- processEvent010_9: the Path you walk is your own

-- The children in the cave (processEvent045_n), spawned by the duty.
CHILDREN = {
	[1000957] = 1, [1000958] = 2, [1000959] = 3, [1000960] = 4, [1000961] = 5,
};

-- The Waking Sands staff before the mission (processEvent000_n) and after
-- it (processEvent060_n). Nenekani names herself in both blocks and the
-- door warden's lines are Sahja Zhwan's (she guards the door in man40600);
-- the rest are matched by voice and not verified.
STAFF_BEFORE = {
	[SERANELIEN] = 1, [FENANA] = 2, [GODFREY] = 3, [NENEKANI] = 4,
	[NONORU] = 5, [SAHJA_ZHWAN] = 6, [UNA_TAYUUN] = 7,
};
STAFF_AFTER = {
	[SERANELIEN] = 2, [NENEKANI] = 3, [GODFREY] = 4, [FENANA] = 5, [SAHJA_ZHWAN] = 6,
};

-- Doors and triggers
ULDAH_MARKET_ENTRANCE	= 1090265;
REVENANTS_TOLL_TRIGGER	= 1090369;	-- Camp Revenant's Toll: the patrol is called away
IMPERIALS_STOP_TRIGGER	= 1090370;	-- where the patrol stops, east along the road
CAVE_EXIT_TRIGGER		= 1090371;	-- the cave's way out (spawned by the duty)

-- Quest Markers (11000000 + quest index * 100 + n). Not probed: guesses.
MRKR_CAPTAIN			= 11001901;
MRKR_REVENANTS_TOLL		= 11001902;
MRKR_IMPERIALS			= 11001903;
MRKR_CAVE_EXIT			= 11001904;
MRKR_ULDAH_ENTRANCE		= 11001905;

-- Places
WAKING_SANDS_AREA		= 3;	-- Minfilia and the staff
WAKING_SANDS_AUDIENCE	= 4;	-- the same, with the Resistance in Minfilia's office
WAKING_SANDS_DOOR		= {-205.25, 0, -160, 1.55};
WAKING_SANDS_HALL		= {-142.75, 1, -160, -1.6};
WAKING_SANDS_OFFICE		= {-129.5, 1.2, -160, 1.57};	-- inside Minfilia's door
REVENANTS_TOLL_WAKE		= {190, -210.0, 18.9, -690.0, 1.57};	-- man40650 ends here

-- Rewards
REWARD_GIL				= 138000;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	local data = quest:GetData();

	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(TATARU, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(RESISTANCE_CAPTAIN, QFLAG_TALK);
	elseif (sequence == SEQ_010) then
		local heard = true;
		for npc, member in pairs(MEMBERS) do
			if not data:GetFlag(member.flag) then heard = false; end
		end
		quest:SetENpc(RESISTANCE_CAPTAIN, heard and QFLAG_TALK or QFLAG_NONE);
		for npc, member in pairs(MEMBERS) do
			quest:SetENpc(npc, data:GetFlag(member.flag) and QFLAG_NONE or QFLAG_TALK);
		end
	elseif (sequence == SEQ_020) then
		quest:SetENpc(IMPERIALS_STOP_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_045) then
		for npc in pairs(CHILDREN) do
			quest:SetENpc(npc);
		end
		quest:SetENpc(CAVE_EXIT_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_050) then
		quest:SetENpc(TATARU, QFLAG_REWARD);
	end

	if (sequence == SEQ_000) then
		for npc in pairs(MEMBERS) do
			quest:SetENpc(npc);
		end
	end
	if (sequence == SEQ_000 or sequence == SEQ_010) then
		quest:SetENpc(MINFILIA);
		quest:SetENpc(TATARU);
	end
	if (sequence == SEQ_015) then
		quest:SetENpc(REVENANTS_TOLL_TRIGGER, QFLAG_PUSH, false, true);
	end
	if (sequence == SEQ_015 or sequence == SEQ_020) then
		quest:SetENpc(MINFILIA);
		quest:SetENpc(TATARU);
		quest:SetENpc(PERCEVAINS);
		quest:SetENpc(UNA_TAYUUN);
	end
	if (sequence == SEQ_050) then
		quest:SetENpc(MINFILIA);
	end

	-- The Waking Sands staff, and the way in from Ul'dah.
	local staff = (sequence == SEQ_050) and STAFF_AFTER or STAFF_BEFORE;
	if (sequence == SEQ_ACCEPT or sequence == SEQ_000 or sequence == SEQ_010 or sequence == SEQ_050) then
		for npc in pairs(staff) do
			quest:SetENpc(npc);
		end
	end
	if (sequence ~= SEQ_045) then
		quest:SetENpc(ULDAH_MARKET_ENTRANCE, QFLAG_PUSH, false, true);
	end
end

function companionArgs(player)
	return player:GetSNpcNickname(), player:GetSNpcSkin(), player:GetSNpcPersonality(), player:GetSNpcCoordinate(), player:GetInitialTown();
end

function warpTo(player, spot)
	GetWorldManager():DoZoneChange(player, spot[1], nil, 0, 15, spot[2], spot[3], spot[4], spot[5]);
end

function warpToWakingSands(player, area, spot)
	GetWorldManager():DoZoneChange(player, 181, "PrivateAreaMasterPast", area, 15, spot[1], spot[2], spot[3], spot[4]);
end

-- The Waking Sands area for this point in the quest: the audience while
-- the Resistance is there, the usual one otherwise.
function wakingSandsArea(quest)
	local sequence = quest:getSequence();
	if (sequence == SEQ_000 or sequence == SEQ_010) then
		return WAKING_SANDS_AUDIENCE;
	end
	return WAKING_SANDS_AREA;
end

function talkEvent(player, quest, event, ...)
	callClientFunction(player, "delegateEvent", player, quest, event, ...);
end

function onTalk(player, quest, npc)
	local sequence = quest:getSequence();
	local classId = npc:GetActorClassId();
	local data = quest:GetData();

	if (sequence == SEQ_ACCEPT and classId == TATARU) then
		-- the summons to the hall and the captain's plan (man40600); accepting
		-- ends on an after-warp fade into the audience
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "pES", companionArgs(player));
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
			player:EndEvent();
			warpToWakingSands(player, WAKING_SANDS_AUDIENCE, WAKING_SANDS_OFFICE);
			return;
		end
	elseif (sequence == SEQ_000 and classId == RESISTANCE_CAPTAIN) then
		-- Minfilia questions the plan (man40610)
		talkEvent(player, quest, "pE10", companionArgs(player));
		player:EndEvent();
		quest:StartSequence(SEQ_010);
		return;
	elseif (sequence == SEQ_010 and classId == RESISTANCE_CAPTAIN) then
		local heard = true;
		for npc, member in pairs(MEMBERS) do
			if not data:GetFlag(member.flag) then heard = false; end
		end
		if (heard) then
			-- your companion leaves with the captain (man40615, after-warp fade)
			talkEvent(player, quest, "pE15", companionArgs(player));
			player:EndEvent();
			quest:StartSequence(SEQ_015);
			warpToWakingSands(player, WAKING_SANDS_AREA, WAKING_SANDS_HALL);
			return;
		end
		talkEvent(player, quest, "processEvent010_" .. CAPTAIN_WAITING);
	elseif (classId == RESISTANCE_CAPTAIN) then
		talkEvent(player, quest, "processEvent010_" .. CAPTAIN_TALE);
	elseif (MEMBERS[classId] ~= nil) then
		talkEvent(player, quest, "processEvent010_" .. MEMBERS[classId].event);
		data:SetFlag(MEMBERS[classId].flag);
	elseif (CHILDREN[classId] ~= nil) then
		talkEvent(player, quest, "processEvent045_" .. CHILDREN[classId]);
	elseif (sequence == SEQ_050 and classId == TATARU) then
		-- Minfilia hears what became of the Resistance (man40660)
		talkEvent(player, quest, "pE60", companionArgs(player));
		-- Completion reward from the client's quest reward sheet: 50 EXP + REWARD_GIL.
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 50, 1, 1, 2);
		player:AddExp(50, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddGil(REWARD_GIL);
		player:EndEvent();
		player:CompleteQuest(quest);
		warpToWakingSands(player, WAKING_SANDS_AREA, WAKING_SANDS_HALL);
		return;
	elseif (sequence == SEQ_050 and classId == MINFILIA) then
		talkEvent(player, quest, "pE61", companionArgs(player));
	elseif (sequence == SEQ_050 and STAFF_AFTER[classId] ~= nil) then
		talkEvent(player, quest, "processEvent060_" .. STAFF_AFTER[classId]);
	elseif ((sequence == SEQ_015 or sequence == SEQ_020) and classId == MINFILIA) then
		talkEvent(player, quest, "pE16", companionArgs(player));
	elseif ((sequence == SEQ_015 or sequence == SEQ_020) and classId == TATARU) then
		talkEvent(player, quest, "pE17", companionArgs(player));
	elseif ((sequence == SEQ_015 or sequence == SEQ_020) and classId == PERCEVAINS) then
		talkEvent(player, quest, "pE18", companionArgs(player));
	elseif ((sequence == SEQ_015 or sequence == SEQ_020) and classId == UNA_TAYUUN) then
		talkEvent(player, quest, "processEvent015_4");
	elseif (classId == MINFILIA) then
		talkEvent(player, quest, "processEvent010_" .. ((sequence == SEQ_010) and MINFILIA_AFTER or MINFILIA_BEFORE));
	elseif (classId == TATARU) then
		talkEvent(player, quest, "processEvent010_" .. TATARU_HALL);
	elseif (STAFF_BEFORE[classId] ~= nil) then
		talkEvent(player, quest, "processEvent000_" .. STAFF_BEFORE[classId]);
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onPush(player, quest, npc)
	local sequence = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (sequence == SEQ_015 and classId == REVENANTS_TOLL_TRIGGER) then
		-- the patrol at the camp is called away (man40620; true = no warp)
		talkEvent(player, quest, "processEvent020", true);
		player:EndEvent();
		quest:StartSequence(SEQ_020);
		return;
	elseif (sequence == SEQ_020 and classId == IMPERIALS_STOP_TRIGGER) then
		-- where the patrol stops (MAN40625), then the fight
		talkEvent(player, quest, "processEvent025");
		startMan406Content(player, quest);
		return;
	elseif (sequence == SEQ_045 and classId == CAVE_EXIT_TRIGGER) then
		-- you wake by Camp Revenant's Toll (man40650, after-warp fade)
		talkEvent(player, quest, "pE50", companionArgs(player));
		player:EndEvent();
		quest:StartSequence(SEQ_050);
		player:SetMod(modifiersGlobal.MinimumHpLock, 0);
		player:GetZone():ContentFinished();
		warpTo(player, REVENANTS_TOLL_WAKE);
		return;
	elseif (classId == ULDAH_MARKET_ENTRANCE) then
		player:EndEvent();
		warpToWakingSands(player, wakingSandsArea(quest), WAKING_SANDS_DOOR);
		return;
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

-- The patrol fight, the airship and the cave: one duty entered in place
-- (spawnType 0x16) like Man402's. Its director (QuestDirectorMan40601)
-- plays the airship scenes after the fight and moves you into the cave.
function startMan406Content(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Man40601", "SimpleContentMan40601", "Quest/QuestDirectorMan40601");
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

	if (sequence == SEQ_000 or sequence == SEQ_010) then
		return MRKR_CAPTAIN;
	elseif (sequence == SEQ_015) then
		return MRKR_REVENANTS_TOLL;
	elseif (sequence == SEQ_020) then
		return MRKR_IMPERIALS;
	elseif (sequence == SEQ_045) then
		return MRKR_CAVE_EXIT;
	elseif (sequence == SEQ_050) then
		return MRKR_ULDAH_ENTRANCE;
	end
end
