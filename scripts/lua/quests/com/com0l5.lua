require ("global")
require ("quest")

--[[

Quest Script

Name: 	An Officer and a Wise Man
Code: 	Com0l5
Id: 	111405
Prereq: Com0l4 complete (a Maelstrom corporal).

The Admiral has gone missing on the day of the Maelstrom's inauguration:
she left, unarmed and alone, for a moot with the pirate crews in a clearing
southwest of Camp Bloodshore. Guincum sends a recruit after her. Brigands
tracking her waylay you on the way (a duty entered in place,
SimpleContentCom0l501). Merlwyb waits in the clearing with Urianger and
invites you to the ceremony; Zanthael takes you up the lift to the Bridge
(the lift and inauguration cutscenes), and afterwards Thancred speaks of the
Archons, the Allseer, and the road to Gridania and Ul'dah.

The client script (com0l5) names the events; seed 127 holds the cast, the
clearing trigger and the brigands. The Bridge (private layout prv_s0_hal01)
has no geometry of its own: it dresses the Maelstrom Command room (mlt01), so
the gathering after the ceremony stands in Maelstrom Command.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Find the Admiral at the clearing southwest of Camp Bloodshore.
SEQ_005	= 5;	-- Speak with Merlwyb in the clearing.
SEQ_010	= 10;	-- Take Zanthael's lift up to the Bridge.
SEQ_015	= 15;	-- Speak with Thancred after the ceremony.

-- Quest Actors
GUINCUM					= 1500199;
MERLWYB					= 1001568;
URIANGER				= 1500204;
ZANTHAEL				= 1000351;
THANCRED				= 1000185;
CORSAIR_FREE			= 1000706;	-- "free to join the Admiral?"
CORSAIR_SALTWIFE		= 1000707;	-- "stubborn as a sea lion"
BARRACUDA_KNIGHT		= 1000095;	-- "What a speech!"

-- Triggers
CLEARING				= 1090327;

-- Places
CLEARING_ROAD			= {130, 1043.0, 70.0, -850.0, -1.57};
MAELSTROM_HALL			= {232, 163.0, 0.0, -178.0, -1.57};

-- Rewards (the client's reward sheet row: an EXP tier in slot 1, seals in slot 5)
REWARD_EXP				= 1541;
REWARD_SEALS			= 300;
COMPANY					= 1;

-- The gathering after the ceremony: each bystander's talk.
CROWD = {
	[CORSAIR_FREE]		= "processEvent_015_01",
	[CORSAIR_SALTWIFE]	= "processEvent_015_02",
	[GUINCUM]			= "processEvent_015_03",
	[BARRACUDA_KNIGHT]	= "processEvent_015_04",
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(GUINCUM, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(CLEARING, QFLAG_PUSH, false, true);
		quest:SetENpc(GUINCUM);
	elseif (sequence == SEQ_005) then
		quest:SetENpc(MERLWYB, QFLAG_TALK);
		quest:SetENpc(URIANGER);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ZANTHAEL, QFLAG_TALK);
		quest:SetENpc(MERLWYB);
		quest:SetENpc(URIANGER);
	elseif (sequence == SEQ_015) then
		quest:SetENpc(THANCRED, QFLAG_REWARD);
		for classId in pairs(CROWD) do
			quest:SetENpc(classId);
		end
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (sequence == SEQ_ACCEPT and classId == GUINCUM) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventGUINCUMStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (sequence == SEQ_000 and classId == GUINCUM) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_000");
	elseif (sequence == SEQ_005 and classId == MERLWYB) then
		-- the moot, the brigands, and an invitation to the ceremony
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_005_merlwyb");
		quest:StartSequence(SEQ_010);
	elseif (sequence == SEQ_010 and classId == MERLWYB) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_005_merlwyb_01");
	elseif (classId == URIANGER) then
		-- his apology for the familiar, and the calumnies against him
		local first = not quest:GetData():GetFlag(0);
		callClientFunction(player, "delegateEvent", player, quest, first and "processEvent_005_uri" or "processEvent_005_uri_01");
		quest:GetData():SetFlag(0);
	elseif (sequence == SEQ_010 and classId == ZANTHAEL) then
		-- the lift and the inauguration; the cutscene ends on a warp
		local ride = callClientFunction(player, "delegateEvent", player, quest, "processEvent_elevator_nq1");
		if (ride == 1) then
			quest:StartSequence(SEQ_015);
			player:EndEvent();
			GetWorldManager():DoZoneChange(player, MAELSTROM_HALL[1], nil, 0, 15,
				MAELSTROM_HALL[2], MAELSTROM_HALL[3], MAELSTROM_HALL[4], MAELSTROM_HALL[5]);
			return;
		end
	elseif (sequence == SEQ_015 and CROWD[classId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, CROWD[classId]);
	elseif (sequence == SEQ_015 and classId == THANCRED) then
		-- the Archons, the Allseer, and the road east
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_015");
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
	if (npc:GetActorClassId() == CLEARING and quest:getSequence() == SEQ_000) then
		startCom0l5Content(player, quest);
		return;
	end
	player:EndEvent();
end

-- The brigands, a duty entered in place (spawnType 0x16). Its director
-- (QuestDirectorCom0l501) sends you on to Merlwyb once they fall.
function startCom0l5Content(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Com0l501", "SimpleContentCom0l501", "Quest/SimpleQuestBattle/QuestDirectorCom0l501");
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
