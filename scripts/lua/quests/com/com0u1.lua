require ("global")
require ("quest")

--[[

Quest Script

Name: 	Career Opportunities
Code: 	Com0u1
Id: 	111801
Prereq: Level 22, not in another Grand Company.

The Immortal Flames' test of a would-be recruit. Flame Lieutenant Aubrey
sends you to win over Taylor, a wealthy merchant who refuses the Flames his
support. Taylor's price is Urianger: find the Archon by the docks southeast
of him in Western Thanalan. Urianger sets a familiar on you (a duty entered
in place, SimpleContentCom0u101) and vanishes; Taylor is pleased enough
with what you learned to back the Flames, and Aubrey invites you to enlist:
he offers the interim enlistment next (Com0u2).

The client script (com0u1) names the events; seed 122 holds the cast, the
dock trigger and the familiar.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Win Taylor over to the Immortal Flames.
SEQ_010	= 10;	-- Find Urianger by the docks southeast of Taylor.
SEQ_030	= 30;	-- Return to Taylor.
SEQ_040	= 40;	-- Return to Aubrey at the Hall of Flames.

-- Quest Actors
AUBREY					= 1500198;
TAYLOR					= 1001447;

-- Triggers
URIANGER_CAMP			= 1090323;

-- Quest Flags
FLAG_MET_URIANGER		= 0;	-- his scene played; the camp now starts the fight

-- Places
CAMP_EDGE				= {172, -1725.0, 57.0, 101.0, 0.0};
CAMP_OUTSIDE			= {172, -1725.0, 57.0, 101.0, 3.14};

GC_IMMORTAL_FLAMES		= 3;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(AUBREY, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(TAYLOR, QFLAG_TALK);
		quest:SetENpc(AUBREY);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(URIANGER_CAMP, QFLAG_PUSH, false, true);
		quest:SetENpc(TAYLOR);
	elseif (sequence == SEQ_030) then
		quest:SetENpc(TAYLOR, QFLAG_TALK);
	elseif (sequence == SEQ_040) then
		quest:SetENpc(AUBREY, QFLAG_REWARD);
		quest:SetENpc(TAYLOR);
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (sequence == SEQ_ACCEPT and classId == AUBREY) then
		-- One company at a time: another's members get the officer's brush-off.
		if (player.gcCurrent ~= 0 and player.gcCurrent ~= GC_IMMORTAL_FLAMES) then
			callClientFunction(player, "eventTalkExclusive");
			callClientFunction(player, "eventTalkStepBreak");
			player:EndEvent();
			return;
		end
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventAUBREYStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (sequence == SEQ_000 and classId == AUBREY) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_000");
	elseif (sequence == SEQ_000 and classId == TAYLOR) then
		-- his price: win him Urianger
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010");
		quest:StartSequence(SEQ_010);
	elseif (sequence == SEQ_010 and classId == TAYLOR) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010_1");
	elseif (sequence == SEQ_030 and classId == TAYLOR) then
		-- the report, and his backing
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_040");
		quest:StartSequence(SEQ_040);
	elseif (sequence == SEQ_040 and classId == TAYLOR) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_040_1");
	elseif (sequence == SEQ_040 and classId == AUBREY) then
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
			-- Urianger by the docks. The scene fades in only after a real
			-- warp (entering the duty in place isn't one), so it ends at the
			-- spot's edge; walking back in starts the fight.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_020");
			quest:GetData():SetFlag(FLAG_MET_URIANGER);
			player:EndEvent();
			warpTo(player, CAMP_EDGE);
			return;
		end
		startCom0u1Content(player, quest);
		return;
	end

	player:EndEvent();
end

-- Urianger's familiar, a duty entered in place (spawnType 0x16) on Western
-- Thanalan's own map. Its director (QuestDirectorCom0u101) plays Urianger's
-- parting scene once the familiar falls.
function startCom0u1Content(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Com0u101", "SimpleContentCom0u101", "Quest/SimpleQuestBattle/QuestDirectorCom0u101");
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
