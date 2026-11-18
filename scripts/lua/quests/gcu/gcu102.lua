require ("global")
require ("quest")

--[[

Quest Script

Name: 	Like Father, Like Son
Code: 	Gcu102
Id: 	111827
Prereq: It Kills with Fire (Gcu101), a sworn member of the Immortal Flames (company_gate in quest_offers.rs).

Imperial troops have set out from Silvertear Falls and march on Thanalan.
Aubrey sends you north of Camp Black Brush to join High Commander Jakys
Ryder's Free Brigade. Ryder hands you an imperial disruptor and sends you to
the cave to the north-west, where the Garleans fall on you (a duty entered in
place, SimpleContentGcu10201). The Echo shows you the surviving centurion's
memory of Nael van Darnus casting Cid from a precipice in the Crypt of Xandes
(cutscene gc01u210). Ryder sends you to the Ul'dah airship landing, where Cid,
alive and well, tells you what he knows of Meteor and the lunar transmitter.

The client script (gcu102) names the events; seed 145 holds the brigade, the
cave trigger, the Garleans and the fallen imperials. Cid and the landing's
cast already stand at the airship landing (seed 134).

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Find High Commander Ryder north of Camp Black Brush.
SEQ_005	= 5;	-- Patrol to the cave to the north-west.
SEQ_010	= 10;	-- Find out what the surviving Garlean knows.
SEQ_015	= 15;	-- Report what the Echo showed to Ryder.
SEQ_020	= 20;	-- Find Cid at the Ul'dah airship landing.

-- Quest Actors
AUBREY					= 1500198;
RYDER					= 1001815;	-- Flame Commander Jakys Ryder
CLOVISSOIX				= 1001816;
DHAVHA					= 1001817;	-- Flame Private Dhavha
MAKAGO					= 1001818;	-- Flame Private Makago Nokago
CENTURION				= 1001819;	-- the Garlean who lives through the fight
HOPLOMACHUS				= 1001820;
SIGNIFER				= 1001821;
LAQUEARIUS				= 1001822;
CID						= 1001572;
RYCHARDE				= 1001718;
AUTGAR					= 1001714;
AHLDBYRT				= 1001715;
H_CIDJAA				= 1001713;
GOODIFE					= 1001717;
GUILLESTET				= 1001712;

-- Triggers
CAVE_MOUTH				= 1090334;

-- Places
CAVE_EDGE				= {170, -15.2, 195.0, -547.2, -2.49};	-- between the cave and the brigade: both in view

-- Key items
IMPERIAL_DISRUPTOR		= 11000421;

-- Rewards (the client's reward sheet row: EXP tier 7 in slot 1, seals in slot 5)
REWARD_EXP				= 1541;
REWARD_SEALS			= 1000;
COMPANY					= 3;

-- Ryder's men, every sequence.
BRIGADE = {
	[CLOVISSOIX]	= "processEvent000_3",	-- flowery talk
	[DHAVHA]		= "processEvent000_4",	-- the chest of gil
	[MAKAGO]		= "processEvent000_5",	-- the new weapons
};

-- The imperials left lying after the fight.
FALLEN = {
	[HOPLOMACHUS]	= "processEvent010_3",
	[SIGNIFER]		= "processEvent010_4",
	[LAQUEARIUS]	= "processEvent010_5",
};

-- The airship landing, closed while the Ironworks see to it.
LANDING_CROWD = {
	[RYCHARDE]		= "processEvent025_2",
	[AUTGAR]		= "processEvent025_3",
	[AHLDBYRT]		= "processEvent025_4",
	[H_CIDJAA]		= "processEvent025_5",
	[GOODIFE]		= "processEvent025_6",
	[GUILLESTET]	= "processEvent025_7",
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(AUBREY, QFLAG_TALK);
		return;
	end

	if (sequence == SEQ_000) then
		quest:SetENpc(RYDER, QFLAG_TALK);
		quest:SetENpc(AUBREY);
	elseif (sequence == SEQ_005) then
		quest:SetENpc(CAVE_MOUTH, QFLAG_PUSH, false, true);
		quest:SetENpc(RYDER);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(CENTURION, QFLAG_TALK);
		quest:SetENpc(RYDER);
	elseif (sequence == SEQ_015) then
		quest:SetENpc(RYDER, QFLAG_TALK);
		quest:SetENpc(CENTURION);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(CID, QFLAG_REWARD);
		for classId in pairs(LANDING_CROWD) do
			quest:SetENpc(classId);
		end
		quest:SetENpc(RYDER);
	end

	if (sequence <= SEQ_015) then
		for classId in pairs(BRIGADE) do
			quest:SetENpc(classId);
		end
	end
	if (sequence == SEQ_010 or sequence == SEQ_015) then
		for classId in pairs(FALLEN) do
			quest:SetENpc(classId);
		end
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (sequence == SEQ_ACCEPT and classId == AUBREY) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (sequence == SEQ_000 and classId == AUBREY) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_2");
	elseif (BRIGADE[classId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, BRIGADE[classId]);
	elseif (sequence <= SEQ_005 and classId == RYDER) then
		-- the march on Thanalan, the cave, and the disruptor
		callClientFunction(player, "delegateEvent", player, quest, "processEvent005");
		if (sequence == SEQ_000) then
			player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(IMPERIAL_DISRUPTOR, 1, 1);
			quest:StartSequence(SEQ_005);
		end
	elseif (sequence == SEQ_010 and classId == RYDER) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010_2");
	elseif (sequence == SEQ_010 and classId == CENTURION) then
		-- the Echo: 1 sees into his past (van Darnus and Cid, gc01u210)
		local echo = callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		if (echo == 1) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent015");
			quest:StartSequence(SEQ_015);
		end
	elseif (sequence >= SEQ_015 and classId == CENTURION) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent015_2");
	elseif (FALLEN[classId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, FALLEN[classId]);
	elseif (sequence == SEQ_015 and classId == RYDER) then
		-- Cid is alive and back in Ul'dah: go and see
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		quest:StartSequence(SEQ_020);
	elseif (sequence == SEQ_020 and LANDING_CROWD[classId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, LANDING_CROWD[classId]);
	elseif (sequence == SEQ_020 and classId == CID) then
		-- the Crypt of Xandes, Meteor, and the lunar transmitter
		callClientFunction(player, "delegateEvent", player, quest, "processEvent025");
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
	if (npc:GetActorClassId() == CAVE_MOUTH and quest:getSequence() == SEQ_005) then
		startGcu102Content(player, quest);
		return;
	end
	player:EndEvent();
end

-- The cave mouth, a duty entered in place (spawnType 0x16). Its director
-- (QuestDirectorGcu10201) sets you back down at the cave once the Garleans
-- fall.
function startGcu102Content(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Gcu10201", "SimpleContentGcu10201", "Quest/QuestDirectorGcu10201");
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
