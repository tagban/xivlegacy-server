require ("global")
require ("quest")

--[[

Quest Script

Name: 	Appetite for Destruction
Code: 	Com0g6
Id: 	111606
Prereq: Com0g5 complete (a Twin Adder recruit).

Dalamud reddens and the elementals whisper of a great destructive force
sent into the skies. Fulke sends a recruit to Stillglade Fane, where Bowlord
Lewin has gathered archers, lancers and engineers of the Garlond Ironworks.
His spy Arthur, back from Ala Mhigo, is to be met in the clearing west of
Camp Nine Ivies; the recruit is to secure it first. Spiders hold the
clearing (a duty entered in place, SimpleContentCom0g601). Afterwards Cid's
flare drives the beasts off and Arthur rages at the Ironworks (cutscene
com0g510). Back at the Fane, Cid tells of what Arthur saw.

The client script (com0g6) names the events; seed 133 holds the cast, the
clearing trigger and the spiders. The clearing is where com0g510 is
staged, in the East Shroud (zone 151).

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Speak with Lewin at Stillglade Fane.
SEQ_010	= 10;	-- Secure the clearing west of Camp Nine Ivies.
SEQ_020	= 20;	-- Speak with Cid at Stillglade Fane.

-- Quest Actors
FULKE					= 1500200;
LEWIN					= 1000020;
CID						= 1001572;
O_APP_PESI				= 1000033;
SWETHYNA				= 1000680;
CONCESSA				= 1000511;
KINBOROW				= 1000509;
NORBERTILLON			= 1001735;
SUZARI_SOREZARI			= 1001736;

-- Triggers
CLEARING				= 1090331;

-- Places
CLEARING_EDGE			= {151, 1486.0, 21.0, -804.0, -1.57};

-- Rewards (the client's reward sheet row: an EXP tier in slot 1, seals in slot 5)
REWARD_EXP				= 1541;
REWARD_SEALS			= 300;
COMPANY					= 2;

-- Lewin and O-App-Pesi greet a member of the Twin Adder by these two
-- values (enlisted, company); anything else gets their stranger's lines.
ENLISTED				= 1;

-- The Fane before and after the clearing: each one's talk.
FANE_CROWD = {
	[O_APP_PESI]		= {"processEventPesi",			"processEventPesiAfter"},
	[SWETHYNA]			= {"processEventSwethyna",		"processEventSwethynaAfter"},
	[CONCESSA]			= {"processEventConcessa",		"processEventConcessaAfter"},
	[KINBOROW]			= {"processEventKinborow",		"processEventKinborowAfter"},
	[NORBERTILLON]		= {"processEventNorbertillon",	"processEventNorbertillonAfter"},
	[SUZARI_SOREZARI]	= {"processEventSorezari",		"processEventSorezariAfter"},
};

-- Cid's account, as in each company's sixth mission, depends on which of the
-- other two you have heard: 3 for neither, 1 or 2 for one, 4 for both.
CID_LIMSA				= 111406;
CID_ULDAH				= 111806;

local function cidHeard(player, first, second)
	local heardFirst = player:IsQuestCompleted(first);
	local heardSecond = player:IsQuestCompleted(second);
	if (heardFirst and heardSecond) then
		return 4;
	elseif (heardFirst) then
		return 1;
	elseif (heardSecond) then
		return 2;
	end
	return 3;
end

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(FULKE, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(LEWIN, QFLAG_TALK);
		quest:SetENpc(FULKE);
		for classId in pairs(FANE_CROWD) do
			quest:SetENpc(classId);
		end
	elseif (sequence == SEQ_010) then
		quest:SetENpc(CLEARING, QFLAG_PUSH, false, true);
		quest:SetENpc(LEWIN);
		for classId in pairs(FANE_CROWD) do
			quest:SetENpc(classId);
		end
	elseif (sequence == SEQ_020) then
		quest:SetENpc(CID, QFLAG_REWARD);
		quest:SetENpc(LEWIN);
		for classId in pairs(FANE_CROWD) do
			quest:SetENpc(classId);
		end
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (sequence == SEQ_ACCEPT and classId == FULKE) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (sequence == SEQ_000 and classId == FULKE) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventStartAfter");
	elseif (sequence == SEQ_000 and classId == LEWIN) then
		-- the elementals' whispers, Arthur in Ala Mhigo, and the clearing
		callClientFunction(player, "delegateEvent", player, quest, "processEventLewin", ENLISTED, COMPANY);
		quest:StartSequence(SEQ_010);
	elseif (FANE_CROWD[classId] ~= nil) then
		local talk = FANE_CROWD[classId][sequence == SEQ_020 and 2 or 1];
		callClientFunction(player, "delegateEvent", player, quest, talk, ENLISTED, COMPANY);
	elseif (sequence == SEQ_020 and classId == LEWIN) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventLewinAfter");
	elseif (sequence == SEQ_020 and classId == CID) then
		-- what Arthur saw, the new legatus, and the hearts of Gridanians
		callClientFunction(player, "delegateEvent", player, quest, "processEventClear", cidHeard(player, CID_ULDAH, CID_LIMSA));
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
	if (npc:GetActorClassId() == CLEARING and quest:getSequence() == SEQ_010) then
		startCom0g6Content(player, quest);
		return;
	end
	player:EndEvent();
end

-- The clearing, a duty entered in place (spawnType 0x16). Its director
-- (QuestDirectorCom0g601) plays Cid's flare and Arthur's rage once the
-- spiders fall, and sends you back to the Fane.
function startCom0g6Content(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Com0g601", "SimpleContentCom0g601", "Quest/SimpleQuestBattle/QuestDirectorCom0g601");
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
