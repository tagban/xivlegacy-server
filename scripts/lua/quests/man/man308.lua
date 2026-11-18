require ("global")
require ("quest")

--[[

Quest Script

Name: 	Lord Errant
Code: 	Man308
Id: 	110017
Prereq: Man304 complete. Level 38.

Your Path companion asks to meet you at the Gold Court in Ul'dah, away
from the Waking Sands: the two of you will go to the Amalj'aa stronghold of
Paglth'an in Southern Thanalan and use the Echo to win the tribe over
yourselves. At its gates two sylphs join you with word of a Paragon inside;
an Amalj'aa guard spots you and you wake in a cell with prisoners already
tempered by Ifrit. The Amalj'aa summon Ifrit, his flames turn the captives
against you, and once you have fought them and the Amalj'aa off, Ifrit
questions you and has you thrown out at the gates. Tataru hears it all at
the Waking Sands and pays you.

The client script (x9wgjb) names the events; seed 170 holds the triggers,
the prisoners and the fight. Your companion has no actor of their own, so
their lines play at the Gold Court trigger and in the cell. In 1.0 the
captives had to be talked down with a parley; here they are fought like the
Amalj'aa (SimpleContentMan30801, QuestDirectorMan30801).

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Meet your companion at the gates of Paglth'an.
SEQ_010	= 10;	-- Proceed into Paglth'an.
SEQ_020	= 20;	-- Speak with the other prisoners in your cell.
SEQ_050	= 50;	-- Ifrit's summoning: stop the captives and the Amalj'aa.
SEQ_080	= 80;	-- Report to the Waking Sands.

-- Quest Actors
MINFILIA				= 1000843;
TATARU					= 1001046;
SAHJA_ZHWAN				= 1001373;
NENEKANI				= 1001374;
GODFREY					= 1001375;
FENANA					= 1001376;
NONORU					= 1001377;
SERANELIEN				= 1001378;
SATZFLOH				= 1001228;
PERCEVAINS				= 1001229;
UNA_TAYUUN				= 1001230;

CLOUDY_EYED_PRISONER	= 1001390;
EMOTIONLESS_PRISONER	= 1001391;

-- The Waking Sands after Paglth'an: each one's line (processEvent090_n)
CHATTER = {
	[SERANELIEN] = 3, [SAHJA_ZHWAN] = 4, [NENEKANI] = 5, [GODFREY] = 6,
	[FENANA] = 7, [NONORU] = 8, [SATZFLOH] = 9, [PERCEVAINS] = 10, [UNA_TAYUUN] = 11,
};

-- Doors and triggers
ULDAH_MARKET_ENTRANCE	= 1090265;
WAKING_SANDS_EXIT		= 1090160;
GOLD_COURT_TRIGGER		= 1090363;	-- where your companion waits
PAGLTHAN_APPROACH		= 1090364;	-- the meeting with the sylphs
PAGLTHAN_GATES			= 1090365;	-- spotted by the guard
PAGLTHAN_CLEARING		= 1090366;	-- out of the cell to Ifrit's summoning

-- Quest Markers
MRKR_APPROACH			= 11001702;
MRKR_ULDAH_ENTRANCE		= 11001704;
MRKR_GATES				= 11001705;
MRKR_CLOUDY_EYED		= 11001706;
MRKR_EMOTIONLESS		= 11001707;
MRKR_CLEARING			= 11001708;

-- Flags
FLAG_TALKED_CLOUDY		= 0;
FLAG_TALKED_EMOTIONLESS	= 1;

-- Places
WAKING_SANDS_DOOR		= {-205.25, 0, -160, 1.55};
WAKING_SANDS_AREA		= 3;	-- Minfilia and the staff
WAKING_SANDS_HALL		= {-142.75, 1, -160, -1.6};
ULDAH_MARKET_OUTSIDE	= {175, -216.52, 190, 30.5, 2.32};
PAGLTHAN_OUTSIDE		= {174, 1141.0, 317.0, 839.0, 2.3};	-- where the sylphs wait, and where Ifrit throws you out
PAGLTHAN_CELL			= {174, 993.5, 309.5, 984.8, 0.3};	-- the cell, with the prisoners

-- Rewards
REWARD_GIL				= 114000;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(GOLD_COURT_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(PAGLTHAN_APPROACH, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(PAGLTHAN_GATES, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_020) then
		local data = quest:GetData();
		quest:SetENpc(CLOUDY_EYED_PRISONER, data:GetFlag(FLAG_TALKED_CLOUDY) and QFLAG_NONE or QFLAG_TALK);
		quest:SetENpc(EMOTIONLESS_PRISONER, data:GetFlag(FLAG_TALKED_EMOTIONLESS) and QFLAG_NONE or QFLAG_TALK);
		-- On from the start: the flags read back stale right after the
		-- second talk, so onPush checks them instead.
		quest:SetENpc(PAGLTHAN_CLEARING, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_050) then
		quest:SetENpc(PAGLTHAN_CLEARING, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_080) then
		-- The Waking Sands: Tataru, the staff's chatter, the way in and out.
		quest:SetENpc(TATARU, QFLAG_REWARD);
		for npc in pairs(CHATTER) do
			quest:SetENpc(npc);
		end
		quest:SetENpc(ULDAH_MARKET_ENTRANCE, QFLAG_PUSH, false, true);
		quest:SetENpc(WAKING_SANDS_EXIT, QFLAG_NONE, false, true);
	end
end

function companionArgs(player)
	return player:GetSNpcNickname(), player:GetSNpcSkin(), player:GetSNpcPersonality(), player:GetSNpcCoordinate(), player:GetInitialTown();
end

function warpTo(player, spot)
	GetWorldManager():DoZoneChange(player, spot[1], nil, 0, 15, spot[2], spot[3], spot[4], spot[5]);
end

function talkedToBoth(quest)
	local data = quest:GetData();
	return data:GetFlag(FLAG_TALKED_CLOUDY) and data:GetFlag(FLAG_TALKED_EMOTIONLESS);
end

function onTalk(player, quest, npc)
	local sequence = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (sequence == SEQ_020 and (classId == CLOUDY_EYED_PRISONER or classId == EMOTIONLESS_PRISONER)) then
		-- the tempered prisoners welcome you to your new home
		local cloudy = (classId == CLOUDY_EYED_PRISONER);
		callClientFunction(player, "delegateEvent", player, quest, cloudy and "processEvent020_1" or "processEvent020_2");
		-- the flag reads back stale within this hook: check the other one by hand
		local data = quest:GetData();
		data:SetFlag(cloudy and FLAG_TALKED_CLOUDY or FLAG_TALKED_EMOTIONLESS);
		if (data:GetFlag(cloudy and FLAG_TALKED_EMOTIONLESS or FLAG_TALKED_CLOUDY)) then
			-- your companion's plan for when the Amalj'aa come for you
			callClientFunction(player, "delegateEvent", player, quest, "pE20", companionArgs(player));
		end
	elseif (sequence == SEQ_080 and classId == TATARU) then
		-- Minfilia hears of Ifrit; it fades in after a warp
		callClientFunction(player, "delegateEvent", player, quest, "pE90", companionArgs(player));
		-- Completion reward from the client's quest reward sheet: 50 EXP + REWARD_GIL.
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 50, 1, 1, 2);
		player:AddExp(50, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddGil(REWARD_GIL);
		player:EndEvent();
		player:CompleteQuest(quest);
		GetWorldManager():DoZoneChange(player, 181, "PrivateAreaMasterPast", WAKING_SANDS_AREA, 15,
			WAKING_SANDS_HALL[1], WAKING_SANDS_HALL[2], WAKING_SANDS_HALL[3], WAKING_SANDS_HALL[4]);
		return;
	elseif (CHATTER[classId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent090_" .. CHATTER[classId]);
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onPush(player, quest, npc)
	local sequence = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (sequence == SEQ_ACCEPT and classId == GOLD_COURT_TRIGGER) then
		-- your companion's proposal: Paglth'an
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "pES", companionArgs(player));
		if (accepted == 1) then
			callClientFunction(player, "delegateEvent", player, quest, "pE01", companionArgs(player));
			player:AcceptQuest(quest, true);
		end
	elseif (sequence == SEQ_000 and classId == PAGLTHAN_APPROACH) then
		-- the sylphs at the gates, and word of a Paragon; it fades in after a warp
		callClientFunction(player, "delegateEvent", player, quest, "pE10", companionArgs(player));
		player:EndEvent();
		quest:StartSequence(SEQ_010);
		warpTo(player, PAGLTHAN_OUTSIDE);
		return;
	elseif (sequence == SEQ_010 and classId == PAGLTHAN_GATES) then
		-- an Amalj'aa guard; you wake in a cell. It fades in after a warp
		callClientFunction(player, "delegateEvent", player, quest, "pE30", companionArgs(player));
		player:EndEvent();
		quest:StartSequence(SEQ_020);
		warpTo(player, PAGLTHAN_CELL);
		return;
	elseif ((sequence == SEQ_020 and talkedToBoth(quest) or sequence == SEQ_050) and classId == PAGLTHAN_CLEARING) then
		-- Ifrit is summoned and his flames take the captives; in place
		-- (companionArgs must come last in a call or Lua keeps only its first value)
		local nickname, skin, personality, coordinate, town = companionArgs(player);
		callClientFunction(player, "delegateEvent", player, quest, "pE50", nickname, skin, personality, coordinate, town, true);
		quest:StartSequence(SEQ_050);
		startMan308Content(player, quest);
		return;
	elseif (classId == ULDAH_MARKET_ENTRANCE) then
		player:EndEvent();
		GetWorldManager():DoZoneChange(player, 181, "PrivateAreaMasterPast", WAKING_SANDS_AREA, 15,
			WAKING_SANDS_DOOR[1], WAKING_SANDS_DOOR[2], WAKING_SANDS_DOOR[3], WAKING_SANDS_DOOR[4]);
		return;
	elseif (classId == WAKING_SANDS_EXIT) then
		player:EndEvent();
		warpTo(player, ULDAH_MARKET_OUTSIDE);
		return;
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

-- The fight in the clearing, a duty entered in place (spawnType 0x16) like
-- Man300's. Its director (QuestDirectorMan30801) plays Ifrit's questions and
-- the walk back to the gates once the captives and the Amalj'aa are beaten.
function startMan308Content(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Man30801", "SimpleContentMan30801", "Quest/QuestDirectorMan30801");
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

	if (sequence == SEQ_000) then
		return MRKR_APPROACH;
	elseif (sequence == SEQ_010) then
		return MRKR_GATES;
	elseif (sequence == SEQ_020) then
		if (talkedToBoth(quest)) then
			return MRKR_CLEARING;
		end
		local data = quest:GetData();
		local markers = {};
		if (not data:GetFlag(FLAG_TALKED_CLOUDY)) then table.insert(markers, MRKR_CLOUDY_EYED); end
		if (not data:GetFlag(FLAG_TALKED_EMOTIONLESS)) then table.insert(markers, MRKR_EMOTIONLESS); end
		return unpack(markers);
	elseif (sequence == SEQ_050) then
		return MRKR_CLEARING;
	elseif (sequence == SEQ_080) then
		return MRKR_ULDAH_ENTRANCE;
	end
end
