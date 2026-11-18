require ("global")
require ("quest")

--[[

Quest Script

Name: 	Alive
Code: 	Gcl102
Id: 	111427
Prereq: It Kills with Fire (Gcl101), a sworn member of the Maelstrom (company_gate in quest_offers.rs).

An Ironworks airship carrying Cid Garlond has gone down in upper La Noscea.
Guincum sends you to High Storm Commander R'ashaht Rhiki at Camp Iron Lake,
who hands you an imperial disruptor and sends you up the northern pass into
Oakwood, through the imperial operatives also hunting the survivors (a duty
entered in place, SimpleContentGcl10201). At the crash site Gaius van
Baelsar finds you first, and Cid stands him down (cutscene gc01l210). Cid
and his colleagues tell of the Meteor project, Allagan tomestones and
Dalamud; R'ashaht hears it all back at the camp.

The client script (gcl102) names the events; seed 143 holds the cast, the
pass trigger and the imperials. The client names no class for Myrganmoen,
R'ashaht's veteran, so Storm Captain Roehmannsyn stands in.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Report to R'ashaht Rhiki at Camp Iron Lake.
SEQ_010	= 10;	-- Clear the northern pass into Oakwood.
SEQ_020	= 20;	-- Speak with Cid at the crash site.
SEQ_030	= 30;	-- Report to R'ashaht Rhiki.

-- Quest Actors
GUINCUM					= 1500199;
RASHAHT					= 1001810;	-- High Storm Commander R'ashaht Rhiki
MYRGANMOEN				= 1001813;	-- Storm Captain Roehmannsyn stands in
HIDDEN_SUNSET			= 1001814;	-- Storm Lieutenant Hidden Sunset
CID						= 1001572;
EBRELNAUX				= 1060011;
JIJINA					= 1001733;
EBOLAFF					= 1001731;
SAELBMOHT				= 1001732;
SOREZARI				= 1001736;

-- Triggers
NORTHERN_PASS			= 1090333;

-- Places
CRASH_SITE				= {135, -809.0, 47.5, -2402.0, -1.57};

-- Key items
IMPERIAL_DISRUPTOR		= 11000421;

-- Rewards (the client's reward sheet row: EXP tier 7 in slot 1, seals in slot 5)
REWARD_EXP				= 1541;
REWARD_SEALS			= 1000;
COMPANY					= 1;

-- Cid's colleagues at the crash site: each one's talk.
CRASH_CROWD = {
	[EBRELNAUX]	= "processEventEbrelnaux",
	[JIJINA]	= "processEventJijina",
	[EBOLAFF]	= "processEventBolaff",
	[SAELBMOHT]	= "processEventSaelbmoht",
	[SOREZARI]	= "processEventSorezari",
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
		quest:SetENpc(RASHAHT, QFLAG_TALK);
		quest:SetENpc(MYRGANMOEN);
		quest:SetENpc(HIDDEN_SUNSET);
		quest:SetENpc(GUINCUM);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(NORTHERN_PASS, QFLAG_PUSH, false, true);
		quest:SetENpc(RASHAHT);
		quest:SetENpc(MYRGANMOEN);
		quest:SetENpc(HIDDEN_SUNSET);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(CID, QFLAG_TALK);
		for classId in pairs(CRASH_CROWD) do
			quest:SetENpc(classId);
		end
	elseif (sequence == SEQ_030) then
		quest:SetENpc(RASHAHT, QFLAG_REWARD);
		quest:SetENpc(MYRGANMOEN);
		quest:SetENpc(HIDDEN_SUNSET);
		quest:SetENpc(CID);
		for classId in pairs(CRASH_CROWD) do
			quest:SetENpc(classId);
		end
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (sequence == SEQ_ACCEPT and classId == GUINCUM) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (sequence < SEQ_030 and classId == GUINCUM) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventStartAfter");
	elseif (classId == MYRGANMOEN) then
		if (sequence == SEQ_000) then
			callClientFunction(player, "delegateEvent", player, quest, "processEventMyrganmoen");
		elseif (sequence == SEQ_030) then
			callClientFunction(player, "delegateEvent", player, quest, "processEventMyrganmoen3");
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEventMyrganmoen2");
		end
	elseif (classId == HIDDEN_SUNSET) then
		if (sequence == SEQ_000) then
			callClientFunction(player, "delegateEvent", player, quest, "processEventHidden");
		elseif (sequence == SEQ_030) then
			callClientFunction(player, "delegateEvent", player, quest, "processEventHidden3");
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEventHidden2");
		end
	elseif (sequence == SEQ_000 and classId == RASHAHT) then
		-- the crash, the northern pass, and the disruptor (0: first meeting)
		callClientFunction(player, "delegateEvent", player, quest, "processEventRashaht", 0);
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(IMPERIAL_DISRUPTOR, 1, 1);
		quest:StartSequence(SEQ_010);
	elseif ((sequence == SEQ_010 or sequence == SEQ_020) and classId == RASHAHT) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventRashaht2");
	elseif (sequence == SEQ_020 and classId == CID) then
		-- Gaius, the Meteor project, and Dalamud
		callClientFunction(player, "delegateEvent", player, quest, "processEventCid");
		quest:StartSequence(SEQ_030);
	elseif (sequence == SEQ_030 and classId == CID) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventCid2");
	elseif (classId == EBRELNAUX and sequence == SEQ_030) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventEbrelnaux2");
	elseif (CRASH_CROWD[classId] ~= nil and sequence >= SEQ_020) then
		callClientFunction(player, "delegateEvent", player, quest, CRASH_CROWD[classId]);
	elseif (sequence == SEQ_030 and classId == RASHAHT) then
		-- the report, and word to the Chief Admiral
		callClientFunction(player, "delegateEvent", player, quest, "processEventClear");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 5);
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(IMPERIAL_DISRUPTOR, 1);
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
	if (npc:GetActorClassId() == NORTHERN_PASS and quest:getSequence() == SEQ_010) then
		startGcl102Content(player, quest);
		return;
	end
	player:EndEvent();
end

-- The pass, a duty entered in place (spawnType 0x16). Its director
-- (QuestDirectorGcl10201) plays Gaius's arrival and sets you down at the
-- crash site once the imperials fall.
function startGcl102Content(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Gcl10201", "SimpleContentGcl10201", "Quest/QuestDirectorGcl10201");
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
