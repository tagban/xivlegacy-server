require ("global")
require ("quest")

--[[

Quest Script

Name: 	Shadow of the Raven
Code: 	Gcg103
Id: 	111629
Prereq: Two Vans are Better than One (Gcg102), a sworn member of the Order of the Twin Adder (company_gate in quest_offers.rs).

The elementals have whispered a prophecy to Kan-E-Senna. Fulke sends you to
the Elder Seedseer at Stillglade Fane, who reads in it the coming of Nael van
Darnus and means to raise an Irmin Hedge once the Wood Wailers have ranged
the Twelveswood clear of imperials. She sends you to Swethyna, south of Camp
Crimson Bark in the West Shroud. There the Garleans set the wood ablaze and
the greenwrath falls on Wailers and imperials alike (cutscene gc01g310), and
a magitek war machine bars the way out (a duty entered in place,
SimpleContentGcg10301). Once it falls Swethyna counts her dead and thanks
you (cutscene gc01g320). The quest ends there.

The client script (gcg103) names the events; seed 147 holds Kan-E-Senna,
Grand Serpent Marshal Brookstone (the client's "Swethryk" talk), the ranging
trigger and the war machine.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Present yourself to Kan-E-Senna at Stillglade Fane.
SEQ_010	= 10;	-- Report to Swethyna south of Camp Crimson Bark.
SEQ_020	= 20;	-- Overcome the Garlean war machine.

-- Quest Actors
FULKE					= 1500200;
KAN_E_SENNA				= 1001569;
PESI					= 1000033;	-- O-App-Pesi
BROOKSTONE				= 1060025;	-- Grand Serpent Marshal Brookstone

-- Triggers
RANGING					= 1090336;

-- Places
RANGING_GROUND			= {153, -1305.0, 0.0, -222.0, -2.36};	-- set down here when the machine falls

-- Rewards (the client's reward sheet row: EXP tier 6 in slot 1, seals in slot 5)
REWARD_EXP				= 1322;
REWARD_SEALS			= 1500;
COMPANY					= 2;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(FULKE, QFLAG_TALK);
		return;
	end

	if (sequence == SEQ_000) then
		quest:SetENpc(KAN_E_SENNA, QFLAG_TALK);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(RANGING, QFLAG_PUSH, false, true);
	end
	quest:SetENpc(FULKE);
	quest:SetENpc(PESI);
	quest:SetENpc(BROOKSTONE);
end

function onTalk(player, quest, npc)
	local sequence = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (sequence == SEQ_ACCEPT and classId == FULKE) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (classId == FULKE) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventStartAfter");
	elseif (classId == PESI) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventPesi");
	elseif (classId == BROOKSTONE) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventSwethryk");
	elseif (sequence == SEQ_000 and classId == KAN_E_SENNA) then
		-- the prophecy, the Irmin Hedge, and the ranging. (0, 0) greets a
		-- Twin Adder; (0, 1) a white mage, (1, 1) both, (1, 0) neither.
		callClientFunction(player, "delegateEvent", player, quest, "processEventSenna", 0, 0);
		quest:StartSequence(SEQ_010);
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onPush(player, quest, npc)
	if (npc:GetActorClassId() == RANGING and quest:getSequence() == SEQ_010 and player:GetDirector() == nil) then
		-- the bombardment and the greenwrath
		callClientFunction(player, "delegateEvent", player, quest, "processEventNQ01");
		quest:StartSequence(SEQ_020);
		startGcg103Content(player, quest);
		return;
	end
	player:EndEvent();
end

-- The war machine, a duty entered in place (spawnType 0x16). Its director
-- (QuestDirectorGcg10301) plays the aftermath and closes the quest once the
-- machine falls.
function startGcg103Content(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Gcg10301", "SimpleContentGcg10301", "Quest/SimpleQuestBattle/QuestDirectorGcg10301");
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

-- The machine is down: Swethyna's count of the dead, and her thanks.
function finishGcg103(player, quest)
	callClientFunction(player, "delegateEvent", player, quest, "processEventNQ02");
	callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 5);
	player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
	player:AddSeals(COMPANY, REWARD_SEALS);
	player:CompleteQuest(quest);
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
