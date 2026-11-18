require ("global")
require ("quest")

--[[

Quest Script

Name: 	Breaking the Seals
Code: 	Com0g1
Id: 	111601
Prereq: Level 22, not in another Grand Company.

The Order of the Twin Adder's test of a would-be recruit. Serpent
Lieutenant Fulke sends you to Quarrymill to drive out Ailith, an Ul'dahn
thaumaturge said to be cursing the Twelveswood's trees. Ailith will leave
only once the Archon Urianger, who has been burning glyphs into the trees,
is caught; her scouts place him southwest of Quarrymill. Urianger sets a
familiar on you (a duty entered in place, SimpleContentCom0g101) and
vanishes; Ailith accepts your report, swears a sealed oath to the wood, and
Fulke takes it and invites you to enlist: he offers the interim enlistment
next (Com0g2).

The client script (com0g1) names the events; seed 122 holds the cast, the
glyph-site trigger and the familiar.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Find Ailith near Quarrymill and drive her from the wood.
SEQ_010	= 10;	-- Find Urianger southwest of Quarrymill.
SEQ_030	= 30;	-- Return to Ailith near Quarrymill.
SEQ_040	= 40;	-- Return to Fulke at the Adders' Nest.

-- Quest Actors
FULKE					= 1500200;
AILITH					= 1001628;

-- Triggers
URIANGER_CAMP			= 1090322;

-- Quest Flags
FLAG_MET_URIANGER		= 0;	-- his scene played; the camp now starts the fight

-- Places
CAMP_EDGE				= {154, 1191.0, 0.0, 1090.0, 1.57};
CAMP_OUTSIDE			= {154, 1191.0, 0.0, 1090.0, -1.57};

GC_TWIN_ADDER			= 2;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(FULKE, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(AILITH, QFLAG_TALK);
		quest:SetENpc(FULKE);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(URIANGER_CAMP, QFLAG_PUSH, false, true);
		quest:SetENpc(AILITH);
	elseif (sequence == SEQ_030) then
		quest:SetENpc(AILITH, QFLAG_TALK);
	elseif (sequence == SEQ_040) then
		quest:SetENpc(FULKE, QFLAG_REWARD);
		quest:SetENpc(AILITH);
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (sequence == SEQ_ACCEPT and classId == FULKE) then
		-- One company at a time: another's members get the officer's brush-off.
		if (player.gcCurrent ~= 0 and player.gcCurrent ~= GC_TWIN_ADDER) then
			callClientFunction(player, "eventTalkExclusive");
			callClientFunction(player, "eventTalkStepBreak");
			player:EndEvent();
			return;
		end
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (sequence == SEQ_000 and classId == FULKE) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventStartAfter");
	elseif (sequence == SEQ_000 and classId == AILITH) then
		-- she'll go once Urianger is caught
		callClientFunction(player, "delegateEvent", player, quest, "processEventAilithShiren");
		quest:StartSequence(SEQ_010);
	elseif (sequence == SEQ_010 and classId == AILITH) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventAilithShirenFree");
	elseif (sequence == SEQ_030 and classId == AILITH) then
		-- the report, and her sealed oath
		callClientFunction(player, "delegateEvent", player, quest, "processEventAilith");
		quest:StartSequence(SEQ_040);
	elseif (sequence == SEQ_040 and classId == AILITH) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventAilithFree");
	elseif (sequence == SEQ_040 and classId == FULKE) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventClear");
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
			-- Urianger at his glyphs. The scene fades in only after a real
			-- warp (entering the duty in place isn't one), so it ends at the
			-- site's edge; walking back in starts the fight.
			callClientFunction(player, "delegateEvent", player, quest, "processEventUrianger");
			quest:GetData():SetFlag(FLAG_MET_URIANGER);
			player:EndEvent();
			warpTo(player, CAMP_EDGE);
			return;
		end
		startCom0g1Content(player, quest);
		return;
	end

	player:EndEvent();
end

-- Urianger's familiar, a duty entered in place (spawnType 0x16) on the South
-- Shroud's own map. Its director (QuestDirectorCom0g101) plays Urianger's
-- parting scene once the familiar falls.
function startCom0g1Content(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Com0g101", "SimpleContentCom0g101", "Quest/SimpleQuestBattle/QuestDirectorCom0g101");
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
