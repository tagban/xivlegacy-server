require ("global")
require ("quest")

--[[

Quest Script

Name: 	Burning Man
Code: 	Com0u5
Id: 	111805
Prereq: Com0u4 complete (an Immortal Flames recruit).

Flames have been ambushed time and again at the ferry docks of Vesper Bay,
west of Camp Horizon. Aubrey sends a recruit to avenge them: pirates calling
themselves Maelstrom men fall on you there (a duty entered in place,
SimpleContentCom0u501). Afterwards Thancred owns that he counts Urianger
among his friends, and Urianger speaks of the Circle and sends you back to
the city. Aubrey hears your report and sends you to the Royal Promenade,
where General Raubahn addresses the city on the Immortal Flames' reformation
(cutscene com0u610). Thancred waits in the crowd afterwards.

The client script (com0u5) names the events; seed 131 holds the cast, the
two triggers and the pirates. The docks are where the client stages its
Vesper Bay scene (com0u510, Com0u6's); the speech's crowd stands where
com0u610 puts it, on the Royal Promenade in the upper city (zone 209).

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Avenge the Flames at the ferry docks of Vesper Bay.
SEQ_010	= 10;	-- Speak with Thancred at the docks.
SEQ_015	= 15;	-- Speak with Urianger at the docks.
SEQ_020	= 20;	-- Report to Aubrey.
SEQ_025	= 25;	-- Hear General Raubahn on the Royal Promenade.
SEQ_030	= 30;	-- Speak with Thancred after the speech.

-- Quest Actors
AUBREY					= 1500198;
THANCRED				= 1000185;
URIANGER				= 1500204;
FLAME_CAPTAIN			= 1001931;	-- "It's him! Word must be sent to Ul'dah"
BONNY_LASS				= 1000985;	-- "is nowhere safe anymore!?"
GREEDY_MERCHANT			= 1000937;	-- "Setting the chocobos loose"
TITTERING_TRAVELER		= 1000253;	-- "my heart's all aflutter"
SMIRKING_SELLSWORD		= 1000892;	-- "Words are wind"
EAGER_GLADIATOR			= 1000582;	-- "Raubahn's made a Flame of me"
ENRAPTURED_TRAVELER		= 1000255;	-- "victorrry"
WELL_TRAVELED_MERCHANT	= 1000438;	-- "earn bloody coin"

-- Triggers
FERRY_DOCKS				= 1090328;
ROYAL_PROMENADE			= 1090329;

-- Places
FERRY_DOCKS_ROAD		= {172, -1620.0, 59.5, 248.0, 1.57};
PROMENADE_CROWD			= {209, -104.0, 222.3, 198.0, 0.0};

-- The other companies' fifth missions: with both done, Thancred tells you
-- the choice of company is yours.
OTHER_FIFTH_MISSIONS	= {111405, 111605};

-- Rewards (the client's reward sheet row: an EXP tier in slot 1, seals in slot 5)
REWARD_EXP				= 1541;
REWARD_SEALS			= 300;
COMPANY					= 3;

-- The docks after the ambush, and the Royal Promenade after the speech:
-- each bystander's talk.
DOCKS_CROWD = {
	[FLAME_CAPTAIN]		= {"processEvent010_4", "processEvent015_2"},
	[BONNY_LASS]		= {"processEvent010_5", "processEvent015_3"},
	[GREEDY_MERCHANT]	= {"processEvent010_6", "processEvent015_4"},
};
PROMENADE_CROWD_TALK = {
	[TITTERING_TRAVELER]		= "processEvent030_2",
	[SMIRKING_SELLSWORD]		= "processEvent030_3",
	[EAGER_GLADIATOR]			= "processEvent030_4",
	[ENRAPTURED_TRAVELER]		= "processEvent030_5",
	[WELL_TRAVELED_MERCHANT]	= "processEvent030_6",
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(AUBREY, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(FERRY_DOCKS, QFLAG_PUSH, false, true);
		quest:SetENpc(AUBREY);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(THANCRED, QFLAG_TALK);
		quest:SetENpc(URIANGER);
		for classId in pairs(DOCKS_CROWD) do
			quest:SetENpc(classId);
		end
	elseif (sequence == SEQ_015) then
		quest:SetENpc(URIANGER, QFLAG_TALK);
		quest:SetENpc(THANCRED);
		for classId in pairs(DOCKS_CROWD) do
			quest:SetENpc(classId);
		end
	elseif (sequence == SEQ_020) then
		quest:SetENpc(AUBREY, QFLAG_TALK);
	elseif (sequence == SEQ_025) then
		quest:SetENpc(ROYAL_PROMENADE, QFLAG_PUSH, false, true);
		quest:SetENpc(AUBREY);
	elseif (sequence == SEQ_030) then
		quest:SetENpc(THANCRED, QFLAG_REWARD);
		for classId in pairs(PROMENADE_CROWD_TALK) do
			quest:SetENpc(classId);
		end
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (sequence == SEQ_ACCEPT and classId == AUBREY) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventAubreyStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (sequence == SEQ_000 and classId == AUBREY) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_2");
	elseif (sequence == SEQ_010 and classId == THANCRED) then
		-- the pirates, Urianger's friends, and the lies told of him
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		quest:StartSequence(SEQ_015);
	elseif (sequence == SEQ_010 and classId == URIANGER) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010_3");
	elseif (sequence == SEQ_015 and classId == THANCRED) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010_2");
	elseif (sequence == SEQ_015 and classId == URIANGER) then
		-- the chains men make, the Circle, and the truths in the city
		callClientFunction(player, "delegateEvent", player, quest, "processEvent015");
		quest:StartSequence(SEQ_020);
	elseif ((sequence == SEQ_010 or sequence == SEQ_015) and DOCKS_CROWD[classId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, DOCKS_CROWD[classId][sequence == SEQ_010 and 1 or 2]);
	elseif (sequence == SEQ_020 and classId == AUBREY) then
		-- the Maelstrom's pirates, and General Raubahn's address
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		quest:StartSequence(SEQ_025);
	elseif (sequence == SEQ_025 and classId == AUBREY) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_2");
	elseif (sequence == SEQ_030 and PROMENADE_CROWD_TALK[classId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, PROMENADE_CROWD_TALK[classId]);
	elseif (sequence == SEQ_030 and classId == THANCRED) then
		-- the Syndicate's shadows, the Circle's master, and the choice ahead
		local ready = true;
		for _, questId in ipairs(OTHER_FIFTH_MISSIONS) do
			if (not player:IsQuestCompleted(questId)) then
				ready = false;
			end
		end
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030", ready and 1 or 0);
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
	local sequence = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (classId == FERRY_DOCKS and sequence == SEQ_000) then
		startCom0u5Content(player, quest);
		return;
	elseif (classId == ROYAL_PROMENADE and sequence == SEQ_025) then
		-- General Raubahn's address; the cutscene ends on a warp
		callClientFunction(player, "delegateEvent", player, quest, "processEvent025");
		quest:StartSequence(SEQ_030);
		player:EndEvent();
		GetWorldManager():DoZoneChange(player, PROMENADE_CROWD[1], nil, 0, 15,
			PROMENADE_CROWD[2], PROMENADE_CROWD[3], PROMENADE_CROWD[4], PROMENADE_CROWD[5]);
		return;
	end
	player:EndEvent();
end

-- The ambush, a duty entered in place (spawnType 0x16). Its director
-- (QuestDirectorCom0u501) sends you on to Thancred once the pirates fall.
function startCom0u5Content(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Com0u501", "SimpleContentCom0u501", "Quest/SimpleQuestBattle/QuestDirectorCom0u501");
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
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
