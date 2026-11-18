require ("global")
require ("quest")

--[[

Quest Script

Name: 	Engineering Victory
Code: 	Com0l4
Id: 	111404
Prereq: Com0l3 complete (a Maelstrom recruit).

Guincum sends a recruit to the narrow canyon linking upper and eastern La
Noscea to ambush imperial soldiers fleeing the Maelstrom's assault on the
kobold encampments (a duty entered in place, SimpleContentCom0l401). One of
them carried a magitek transceiver; Guincum sends you with it to Ebrelnaux of
the Garlond Ironworks at Millers' Glade in the Coerthas eastern lowlands.
Back at Maelstrom Command he shares what the Ironworks deciphered.

The client script (com0l4) names the events; seed 124 holds the cast, the
canyon trigger and the soldiers. Millers' Glade's spot isn't known, so the
Ironworks party waits at Camp Glory.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Ambush the fleeing imperials in the canyon.
SEQ_010	= 10;	-- Report to Guincum.
SEQ_015	= 15;	-- Deliver the transceiver to Ebrelnaux in Coerthas.
SEQ_020	= 20;	-- Return to Guincum.

-- Quest Actors
GUINCUM					= 1500199;
EBRELNAUX				= 1060011;
NYMIENE					= 1001578;
AERGFLOH				= 1001579;

-- Triggers
CANYON					= 1090324;

-- Key Items
MAGITEK_TRANSCEIVER		= 11000259;

-- Places
CANYON_FLOOR			= {135, -32.0, 48.7, -1443.0, 1.57};

-- Rewards (ZAM: ~1,541 exp, 500 Storm Seals)
REWARD_EXP				= 1541;
REWARD_SEALS			= 500;
COMPANY					= 1;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(GUINCUM, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(CANYON, QFLAG_PUSH, false, true);
		quest:SetENpc(GUINCUM);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(GUINCUM, QFLAG_TALK);
	elseif (sequence == SEQ_015) then
		quest:SetENpc(EBRELNAUX, QFLAG_TALK);
		quest:SetENpc(GUINCUM);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(GUINCUM, QFLAG_REWARD);
		quest:SetENpc(EBRELNAUX);
	end
	if (sequence == SEQ_015 or sequence == SEQ_020) then
		quest:SetENpc(NYMIENE);
		quest:SetENpc(AERGFLOH);
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
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_000_1");
	elseif (sequence == SEQ_010 and classId == GUINCUM) then
		-- the transceiver, and orders for Coerthas
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010");
		quest:StartSequence(SEQ_015);
	elseif (sequence == SEQ_015 and classId == GUINCUM) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010_1");
	elseif (sequence == SEQ_015 and classId == EBRELNAUX) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_015");
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(MAGITEK_TRANSCEIVER, 1);
		quest:StartSequence(SEQ_020);
	elseif (classId == NYMIENE) then
		callClientFunction(player, "delegateEvent", player, quest, sequence == SEQ_015 and "processEventNymiene" or "processEventNymiene_01");
	elseif (classId == AERGFLOH) then
		callClientFunction(player, "delegateEvent", player, quest, sequence == SEQ_015 and "processEventAergfloh" or "processEventAergfloh_01");
	elseif (sequence == SEQ_020 and classId == GUINCUM) then
		-- the deciphered code; the Admiral's next move
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_020");
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
	if (npc:GetActorClassId() == CANYON and quest:getSequence() == SEQ_000) then
		startCom0l4Content(player, quest);
		return;
	end
	player:EndEvent();
end

-- The ambush, a duty entered in place (spawnType 0x16). Its director
-- (QuestDirectorCom0l401) hands over the transceiver once the soldiers fall.
function startCom0l4Content(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Com0l401", "SimpleContentCom0l401", "Quest/SimpleQuestBattle/QuestDirectorCom0l401");
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
