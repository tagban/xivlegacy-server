require ("global")
require ("quest")

--[[

Quest Script

Name: 	The Price of Integrity
Code: 	Com0l1
Id: 	111401
Prereq: Level 22, not in another Grand Company.

The Maelstrom's test of a would-be recruit. Storm Lieutenant Guincum sends
you to Wineport to silence Walcher, a reporter who writes against the
Admiral. Walcher's price is Urianger, the "false prophet" camped on the
cliffs east of Wineport. Urianger sets a familiar on you (a duty entered in
place, SimpleContentCom0l101), a Miqo'te named Y'shtola finds you after the
fight, and Walcher settles for your report and signs a retraction. Guincum
takes it and invites you to enlist: he offers the interim enlistment
next (Com0l2).

The client script (com0l1) names the events; seed 122 holds the cast, the
camp trigger and the familiar.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Travel to Wineport and persuade Walcher.
SEQ_010	= 10;	-- Find Urianger east of Wineport.
SEQ_030	= 30;	-- Return to Walcher in Wineport.
SEQ_040	= 40;	-- Return to Guincum at Maelstrom Command.

-- Quest Actors
GUINCUM					= 1500199;
WALCHER					= 1001629;

-- Triggers
URIANGER_CAMP			= 1090321;

-- Quest Flags
FLAG_MET_URIANGER		= 0;	-- his scene played; the camp now starts the fight

-- Places
CAMP_EDGE				= {130, 1491.0, 54.2, -1300.0, 1.57};
CAMP_OUTSIDE			= {130, 1491.0, 54.2, -1300.0, -1.57};

GC_MAELSTROM			= 1;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(GUINCUM, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(WALCHER, QFLAG_TALK);
		quest:SetENpc(GUINCUM);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(URIANGER_CAMP, QFLAG_PUSH, false, true);
		quest:SetENpc(WALCHER);
	elseif (sequence == SEQ_030) then
		quest:SetENpc(WALCHER, QFLAG_TALK);
	elseif (sequence == SEQ_040) then
		quest:SetENpc(GUINCUM, QFLAG_REWARD);
		quest:SetENpc(WALCHER);
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (sequence == SEQ_ACCEPT and classId == GUINCUM) then
		-- One company at a time: another's members get the officer's brush-off.
		if (player.gcCurrent ~= 0 and player.gcCurrent ~= GC_MAELSTROM) then
			callClientFunction(player, "eventTalkExclusive");
			callClientFunction(player, "eventTalkStepBreak");
			player:EndEvent();
			return;
		end
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventGUINCUMStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (sequence == SEQ_000 and classId == GUINCUM) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_000");
	elseif (sequence == SEQ_000 and classId == WALCHER) then
		-- his price: bring him Urianger
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010");
		quest:StartSequence(SEQ_010);
	elseif (sequence == SEQ_010 and classId == WALCHER) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010_1");
	elseif (sequence == SEQ_030 and classId == WALCHER) then
		-- the report, and the signed retraction
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_040");
		quest:StartSequence(SEQ_040);
	elseif (sequence == SEQ_040 and classId == WALCHER) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_040_1");
	elseif (sequence == SEQ_040 and classId == GUINCUM) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_050");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 1760, 1, 1);
		player:AddExp(1760, player.charaWork.parameterSave.state_mainSkill[0], 0);
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

	if (classId == URIANGER_CAMP and sequence == SEQ_010) then
		if (not quest:GetData():GetFlag(FLAG_MET_URIANGER)) then
			-- Urianger on the cliffs. The scene fades in only after a real
			-- warp (entering the duty in place isn't one), so it ends at the
			-- camp's edge; walking back in starts the fight.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_020");
			quest:GetData():SetFlag(FLAG_MET_URIANGER);
			player:EndEvent();
			warpTo(player, CAMP_EDGE);
			return;
		end
		startCom0l1Content(player, quest);
		return;
	end

	player:EndEvent();
end

-- Urianger's familiar, a duty entered in place (spawnType 0x16) on Eastern
-- La Noscea's own map. Its director (QuestDirectorCom0l101) plays Y'shtola
-- once the familiar falls.
function startCom0l1Content(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Com0l101", "SimpleContentCom0l101", "Quest/SimpleQuestBattle/QuestDirectorCom0l101");
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

function warpTo(player, spot)
	GetWorldManager():DoZoneChange(player, spot[1], nil, 0, 15, spot[2], spot[3], spot[4], spot[5]);
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
