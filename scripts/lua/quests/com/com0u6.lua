require ("global")
require ("quest")

--[[

Quest Script

Name: 	Know Your Enemy
Code: 	Com0u6
Id: 	111806
Prereq: Com0u5 complete (an Immortal Flames recruit).

The Flames have paid Charledore, an engineer of the Garlond Ironworks, for
word of Dalamud, but his reports have stopped. Aubrey sends a recruit to
the airship landing atop the Wellhead Lift, where engineers of the
Ironworks are at work. Their lead tells you Charledore was a Garlean spy who
fled with stolen findings toward Vesper Bay. There he turns on you (a duty
entered in place, SimpleContentCom0u601). Beaten, he spits out Cid's past in
Garlemald and hails Nael van Darnus as Cid arrives (cutscene com0u510).
Cid waits for you at the landing.

The client script (com0u6) names the events; seed 134 holds the cast, the
docks trigger and Charledore. The landing is the Wellhead Lift's top floor
in the upper city (zone 209); the docks are where com0u510 is staged, the
ferry docks Burning Man and Ceruleum Shock use.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Ask after Charledore at the airship landing.
SEQ_005	= 5;	-- Find Charledore at Vesper Bay.
SEQ_010	= 10;	-- Speak with Cid at the airship landing.

-- Quest Actors
AUBREY					= 1500198;
CID						= 1001572;
RYCHARDE				= 1001718;	-- the Ironworks' lead at the landing
AUTGAR					= 1001714;	-- an engineer: "Bugger off!"
AHLDBYRT				= 1001715;	-- an engineer: "Charledore? <spit>"
H_CIDJAA				= 1001713;	-- "Welcome to the airship landing"
GOODIFE					= 1001717;	-- "the fine folk from the Ironworks"
GUILLESTET				= 1001712;	-- "they haven't bought a single drink"

-- Triggers
FERRY_DOCKS				= 1090332;

-- Places
LANDING					= {209, -109.5, 271.0, 160.5, 0.0};

-- Rewards (the client's reward sheet row: an EXP tier in slot 1, seals in slot 5)
REWARD_EXP				= 1541;
REWARD_SEALS			= 300;
COMPANY					= 3;

-- The landing before and after Vesper Bay: each one's talk.
LANDING_CROWD = {
	[AUTGAR]		= {"processEvent_005_01",	"processEvent_010_01"},
	[AHLDBYRT]		= {"processEvent_005_02",	"processEvent_010_02"},
	[H_CIDJAA]		= {"processEvent_005_05",	"processEvent_010_05"},
	[GOODIFE]		= {"processEvent_005_06",	"processEvent_010_06"},
	[GUILLESTET]	= {"processEvent_005_07",	"processEvent_010_07"},
};

-- Cid's account names what the other two companies' sixth missions told
-- you: 0 for neither, 1 for Gridania's (Arthur and Ala Mhigo), 2 for Limsa
-- Lominsa's (the crystals and Dalamud), 3 for both.
CID_GRIDANIA			= 111606;
CID_LIMSA				= 111406;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(AUBREY, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(RYCHARDE, QFLAG_TALK);
		quest:SetENpc(AUBREY);
		for classId in pairs(LANDING_CROWD) do
			quest:SetENpc(classId);
		end
	elseif (sequence == SEQ_005) then
		quest:SetENpc(FERRY_DOCKS, QFLAG_PUSH, false, true);
		quest:SetENpc(RYCHARDE);
		for classId in pairs(LANDING_CROWD) do
			quest:SetENpc(classId);
		end
	elseif (sequence == SEQ_010) then
		quest:SetENpc(CID, QFLAG_REWARD);
		quest:SetENpc(RYCHARDE);
		for classId in pairs(LANDING_CROWD) do
			quest:SetENpc(classId);
		end
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (sequence == SEQ_ACCEPT and classId == AUBREY) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventAUBREYStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (sequence == SEQ_000 and classId == AUBREY) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_000");
	elseif (sequence == SEQ_000 and classId == RYCHARDE) then
		-- Charledore the spy, the stolen findings, and the chase southwest
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_005");
		quest:StartSequence(SEQ_005);
	elseif (sequence == SEQ_010 and classId == RYCHARDE) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010_03");
	elseif (LANDING_CROWD[classId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, LANDING_CROWD[classId][sequence == SEQ_010 and 2 or 1]);
	elseif (sequence == SEQ_010 and classId == CID) then
		-- Cid's past in Garlemald, the recovered findings, and van Darnus
		local heard = 0;
		if (player:IsQuestCompleted(CID_GRIDANIA)) then
			heard = heard + 1;
		end
		if (player:IsQuestCompleted(CID_LIMSA)) then
			heard = heard + 2;
		end
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010", heard);
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
	if (npc:GetActorClassId() == FERRY_DOCKS and quest:getSequence() == SEQ_005) then
		startCom0u6Content(player, quest);
		return;
	end
	player:EndEvent();
end

-- Charledore at the docks, a duty entered in place (spawnType 0x16). Its
-- director (QuestDirectorCom0u601) plays his last words and Cid's arrival
-- once he falls, and sends you back to the landing, before Cid.
function startCom0u6Content(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Com0u601", "SimpleContentCom0u601", "Quest/SimpleQuestBattle/QuestDirectorCom0u601");
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
