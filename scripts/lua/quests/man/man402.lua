require ("global")
require ("quest")

--[[

Quest Script

Name: 	Of Men They Sing
Code: 	Man402
Id: 	110018
Prereq: Man308 complete. Level 42.

A plea for help crackles over the Path's linkpearl. At the Waking Sands
Tataru and Minfilia have traced it to the East Shroud, and your Path
companion is already on the way to Camp Nine Ivies. There the two of you
find the Ala Mhigan Resistance: the call came from one of their scouts,
cut off from her party with imperial hounds on her trail. You find her in a
ravine south-east of the camp and drive off the two bloodhounds, which wear
imperial rings that bend them to the Empire's will. Your companion stays
with the Resistance captain and sends you back to report; at the Waking
Sands Tataru hears it all, and Minfilia reminds the two of you that the
Path does not act without her word.

The client script (x9wfjh) names the events; the push circles, the hounds
and your companion's stand-in are in the game data (triggers 1090367-68,
bnpc 3592-3593). In 1.0 the camp scene led into an instance in which you
followed your companion to the scout; here you make your own way to the
ravine and the fight is entered in place there (SimpleContentMan40201,
QuestDirectorMan40201). The scout and your companion are in the scenes only.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Go to Camp Nine Ivies in the East Shroud.
SEQ_010	= 10;	-- Find the missing Resistance scout.
SEQ_020	= 20;	-- Report to the Waking Sands.

-- Quest Actors
TATARU					= 1001046;
SAHJA_ZHWAN				= 1001373;
NENEKANI				= 1001374;
GODFREY					= 1001375;
FENANA					= 1001376;
NONORU					= 1001377;
SERANELIEN				= 1001378;

-- The Waking Sands staff's lines (processEvent000_n before the rescue,
-- processEvent020_n after). Nenekani names herself in the third; the
-- others are matched by voice.
STAFF = {
	[SERANELIEN] = 1, [SAHJA_ZHWAN] = 2, [NENEKANI] = 3,
	[GODFREY] = 4, [FENANA] = 5, [NONORU] = 6,
};
TATARU_WAITING			= 7;	-- processEvent000_7: Tataru, once you have accepted

-- Doors and triggers
ULDAH_MARKET_ENTRANCE	= 1090265;
NINE_IVIES_TRIGGER		= 1090367;	-- the Resistance at Camp Nine Ivies
SCOUT_CLEARING			= 1090368;	-- the scout and the hounds

-- Quest Markers (11000000 + quest index * 100 + n)
MRKR_TATARU				= 11001801;
MRKR_NINE_IVIES			= 11001802;
MRKR_SCOUT				= 11001803;
MRKR_ULDAH_ENTRANCE		= 11001804;

-- Places
WAKING_SANDS_DOOR		= {-205.25, 0, -160, 1.55};
WAKING_SANDS_AREA		= 3;	-- Minfilia and the staff
WAKING_SANDS_HALL		= {-142.75, 1, -160, -1.6};
SCOUT_RAVINE_EDGE		= {151, 1851.0, 18.7, -1718.0, 3.0};	-- the ravine's north channel, outside the circle

-- Rewards
REWARD_GIL				= 126000;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(TATARU, QFLAG_TALK);
	elseif (sequence == SEQ_000 or sequence == SEQ_010) then
		quest:SetENpc(TATARU);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(TATARU, QFLAG_REWARD);
	end

	-- The Waking Sands: the staff, and the way in from Ul'dah.
	for npc in pairs(STAFF) do
		quest:SetENpc(npc);
	end
	if (sequence == SEQ_ACCEPT or sequence == SEQ_020) then
		quest:SetENpc(ULDAH_MARKET_ENTRANCE, QFLAG_PUSH, false, true);
	end

	if (sequence == SEQ_000) then
		quest:SetENpc(NINE_IVIES_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(SCOUT_CLEARING, QFLAG_PUSH, false, true);
	end
end

function companionArgs(player)
	return player:GetSNpcNickname(), player:GetSNpcSkin(), player:GetSNpcPersonality(), player:GetSNpcCoordinate(), player:GetInitialTown();
end

-- A companion line from a block of nine (one per personality). The text
-- sheet keeps personalities 7 and 8 in the other order, as Man308's does.
PERSONALITY_ROW = {0, 1, 2, 3, 4, 5, 7, 6, 8};
function companionLine(player, base)
	return base + (PERSONALITY_ROW[player:GetSNpcPersonality()] or 0);
end

-- The Resistance fighter your companion learns has fallen at the camp
-- (pE10's last argument, which the scene's text macros read twice):
-- 1 father, 2 mother, 3 brother, 4 sister. Retail's choice isn't known;
-- here it follows the character's id, so it never changes.
function fallenKin(player)
	return 1 + (player.actorId % 4);
end

function warpTo(player, spot)
	GetWorldManager():DoZoneChange(player, spot[1], nil, 0, 15, spot[2], spot[3], spot[4], spot[5]);
end

function warpToWakingSands(player, spot)
	GetWorldManager():DoZoneChange(player, 181, "PrivateAreaMasterPast", WAKING_SANDS_AREA, 15, spot[1], spot[2], spot[3], spot[4]);
end

function onTalk(player, quest, npc)
	local sequence = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (sequence == SEQ_ACCEPT and classId == TATARU) then
		-- the plea on the linkpearl; accepting plays Minfilia's briefing
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "pES", companionArgs(player));
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (sequence == SEQ_020 and classId == TATARU) then
		-- the report, and Minfilia's reproach; it fades in after a warp
		callClientFunction(player, "delegateEvent", player, quest, "pE30", companionArgs(player));
		-- Completion reward from the client's quest reward sheet: 50 EXP + REWARD_GIL.
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 50, 1, 1, 2);
		player:AddExp(50, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddGil(REWARD_GIL);
		player:EndEvent();
		player:CompleteQuest(quest);
		warpToWakingSands(player, WAKING_SANDS_HALL);
		return;
	elseif (classId == TATARU) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_" .. TATARU_WAITING);
	elseif (STAFF[classId] ~= nil) then
		local before = (sequence ~= SEQ_020);
		callClientFunction(player, "delegateEvent", player, quest,
			(before and "processEvent000_" or "processEvent020_") .. STAFF[classId]);
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onPush(player, quest, npc)
	local sequence = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (sequence == SEQ_000 and classId == NINE_IVIES_TRIGGER) then
		-- your companion and the Resistance captain
		-- (companionArgs must come last in a call or Lua keeps only its first value)
		local nickname, skin, personality, coordinate, town = companionArgs(player);
		callClientFunction(player, "delegateEvent", player, quest, "pE10", nickname, skin, personality, coordinate, town, fallenKin(player));
		player:EndEvent();
		quest:StartSequence(SEQ_010);
		return;
	elseif (sequence == SEQ_010 and classId == SCOUT_CLEARING) then
		-- the scout, and the hounds on her
		startMan402Content(player, quest);
		return;
	elseif (classId == ULDAH_MARKET_ENTRANCE) then
		player:EndEvent();
		warpToWakingSands(player, WAKING_SANDS_DOOR);
		return;
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

-- The bloodhounds, a duty entered in place (spawnType 0x16) like Man308's.
-- Its director (QuestDirectorMan40201) plays the scene after the fight.
function startMan402Content(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Man40201", "SimpleContentMan40201", "Quest/QuestDirectorMan40201");
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
		return MRKR_NINE_IVIES;
	elseif (sequence == SEQ_010) then
		return MRKR_SCOUT;
	elseif (sequence == SEQ_020) then
		return MRKR_ULDAH_ENTRANCE;
	end
end
