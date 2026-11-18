require ("global")
require ("quest")

--[[

Quest Script

Name: 	The Mail Must Get Through
Code: 	Com0g4
Id: 	111604
Prereq: Com0g3 complete (a Twin Adder recruit).

Fulke sends a recruit northwest of Gridania, where conjurers raising the
Irmin Hedge have come under imperial attack (a duty entered in place,
SimpleContentCom0g401). An enciphered letter turns up on one of the
soldiers, who proves to have been an Ala Mhigan; Fulke sends you with it to
Radulf at Little Ala Mhigo, south of Camp Drybone (its spot isn't known,
so Radulf waits at the camp). He recognizes the hand of his spy Hagilo,
reads the report and gives you the designs hidden in it for the Adders'
Nest.

The client script (com0g4) names the events; seed 124 holds the cast, the
rite site trigger and the soldiers.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Defend the conjurers northwest of the city.
SEQ_010	= 10;	-- Report to Fulke.
SEQ_015	= 15;	-- Deliver the letter to Radulf at Little Ala Mhigo.
SEQ_020	= 20;	-- Return to Fulke with the designs.

-- Quest Actors
FULKE					= 1500200;
RADULF					= 1001334;

-- Triggers
RITE_SITE				= 1090325;

-- Key Items
IMPERIAL_LETTER			= 11000257;
MAGITEK_DESIGNS			= 11000258;

-- Places
RITE_GROUND				= {150, -336.0, 6.0, -863.0, 0.0};

REWARD_EXP				= 1541;
REWARD_SEALS			= 500;
COMPANY					= 2;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(FULKE, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(RITE_SITE, QFLAG_PUSH, false, true);
		quest:SetENpc(FULKE);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(FULKE, QFLAG_TALK);
	elseif (sequence == SEQ_015) then
		quest:SetENpc(RADULF, QFLAG_TALK);
		quest:SetENpc(FULKE);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(FULKE, QFLAG_REWARD);
		quest:SetENpc(RADULF);
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
	elseif (sequence == SEQ_010 and classId == FULKE) then
		-- the letter was Ala Mhigan; take it to Radulf
		callClientFunction(player, "delegateEvent", player, quest, "processEventFulke");
		quest:StartSequence(SEQ_015);
	elseif (sequence == SEQ_015 and classId == FULKE) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventFulkeFree");
	elseif (sequence == SEQ_015 and classId == RADULF) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventRadulf");
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(IMPERIAL_LETTER, 1);
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(MAGITEK_DESIGNS, 1, 1);
		quest:StartSequence(SEQ_020);
	elseif (sequence == SEQ_020 and classId == RADULF) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventRadulfFree");
	elseif (sequence == SEQ_020 and classId == FULKE) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventClear");
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(MAGITEK_DESIGNS, 1);
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
	if (npc:GetActorClassId() == RITE_SITE and quest:getSequence() == SEQ_000) then
		startCom0g4Content(player, quest);
		return;
	end
	player:EndEvent();
end

-- The defense of the rite, a duty entered in place (spawnType 0x16). Its
-- director (QuestDirectorCom0g401) hands over the letter once the soldiers
-- fall.
function startCom0g4Content(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Com0g401", "SimpleContentCom0g401", "Quest/SimpleQuestBattle/QuestDirectorCom0g401");
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
