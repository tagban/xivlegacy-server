require ("global")
require ("quest")

--[[

Quest Script

Name: 	Careless Whispers
Code: 	Gcu103
Id: 	111829
Prereq: Like Father, Like Son (Gcu102), a sworn member of the Immortal Flames (company_gate in quest_offers.rs).

Teledji Adeledji has told the Syndicate of a new imperial juggernaut, and the
Empire has marched on western Thanalan within hours. Aubrey sends you to the
Royal Promenade, where Flame General Raubahn sends you west of Camp Horizon
ahead of the main host, to gauge the new weapon and to learn what the
Monetarists are about. You arrive to find the Flames sent before you cut
down (cutscene gc01u320), and the juggernaut turns on you (a duty entered in
place, SimpleContentGcu10301). Its fall leaves the wounded, and a dying
sergeant gasps that it was a diversion: the main force strikes at the ferry
docks. There Raubahn hears the docks' losses and notes that you alone
brought a juggernaut down (cutscene gc01u310). The quest ends there.

The client script (gcu103) names the events; seed 148 holds Raubahn, Grand
Flame Marshal Roaille (the client's "Eline" talk), the wounded Flames
("FUMETSU"), the two triggers and the juggernaut.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Find Raubahn on the Royal Promenade.
SEQ_005	= 5;	-- Engage the imperials west of Camp Horizon.
SEQ_010	= 10;	-- Smite the juggernaut.
SEQ_015	= 15;	-- See to the wounded Flames.
SEQ_020	= 20;	-- Make haste to the ferry docks.

-- Quest Actors
AUBREY					= 1500198;
ROAILLE					= 1060026;	-- Grand Flame Marshal Roaille
RAUBAHN					= 1060008;
LIEUTENANT				= 1002027;	-- Second Flame Lieutenant
SERGEANT				= 1002028;	-- Flame Sergeant Second Class
INJURED					= 1002029;	-- Injured Flame Sergeant
SERGEANT2				= 1002030;	-- Flame Sergeant Second Class
FALLEN					= 1002031;	-- Fallen Flame Sergeant, who tells of the diversion

-- Triggers
BATTLEFIELD				= 1090337;
FERRY_DOCKS				= 1090338;

-- Places
BATTLEFIELD_EDGE		= {172, -1912.0, 24.5, -314.0, -2.36};	-- set down here when the juggernaut falls

-- Rewards (the client's reward sheet row: EXP tier 6 in slot 1, seals in slot 5)
REWARD_EXP				= 1322;
REWARD_SEALS			= 1500;
COMPANY					= 3;

-- The wounded after the fight; the fallen sergeant's word moves you on.
WOUNDED = {
	[LIEUTENANT]	= "processEvent_015_FUMETSU01",
	[SERGEANT]		= "processEvent_015_FUMETSU02",
	[INJURED]		= "processEvent_015_FUMETSU03",
	[SERGEANT2]		= "processEvent_015_FUMETSU04",
	[FALLEN]		= "processEvent_015_FUMETSU05",
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
		quest:SetENpc(RAUBAHN, QFLAG_TALK);
		quest:SetENpc(ROAILLE);
	elseif (sequence == SEQ_005) then
		quest:SetENpc(BATTLEFIELD, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_015) then
		for classId in pairs(WOUNDED) do
			quest:SetENpc(classId, classId == FALLEN and QFLAG_TALK or QFLAG_NONE);
		end
	elseif (sequence == SEQ_020) then
		quest:SetENpc(FERRY_DOCKS, QFLAG_PUSH, false, true);
		for classId in pairs(WOUNDED) do
			quest:SetENpc(classId);
		end
	end
	quest:SetENpc(AUBREY);
end

function onTalk(player, quest, npc)
	local sequence = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (sequence == SEQ_ACCEPT and classId == AUBREY) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEvent_000_AUBREYStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (classId == AUBREY) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_000_AUBREYFollow");
	elseif (classId == ROAILLE) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_000_ELINEAfterOffer");
	elseif (sequence == SEQ_000 and classId == RAUBAHN) then
		-- Teledji's juggernaut, the offensive, and a soldier off the Monetarists' payroll
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_005_RAUBAHN");
		quest:StartSequence(SEQ_005);
	elseif (WOUNDED[classId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, WOUNDED[classId]);
		if (sequence == SEQ_015 and classId == FALLEN) then
			quest:StartSequence(SEQ_020);
		end
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onPush(player, quest, npc)
	local sequence = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (classId == BATTLEFIELD and sequence == SEQ_005 and player:GetDirector() == nil) then
		-- the Flames cut down before you arrive
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010_NQ_1");
		quest:StartSequence(SEQ_010);
		startGcu103Content(player, quest);
		return;
	elseif (classId == FERRY_DOCKS and sequence == SEQ_020) then
		-- the docks' losses, and Raubahn's word
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_025_NQ_2");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 5);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddSeals(COMPANY, REWARD_SEALS);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	end
	player:EndEvent();
end

-- The juggernaut, a duty entered in place (spawnType 0x16). Its director
-- (QuestDirectorGcu10301) sets you back down among the wounded once it falls.
function startGcu103Content(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Gcu10301", "SimpleContentGcu10301", "Quest/SimpleQuestBattle/QuestDirectorGcu10301");
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
