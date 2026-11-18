require ("global")
require ("quest")

--[[

Quest Script

Name: 	Deus ex Machina
Code: 	Gcl103
Id: 	111429
Prereq: Alive (Gcl102), a sworn member of the Maelstrom (company_gate in quest_offers.rs).

The Admiral summons you to the Coral Tower. Merlwyb tells you of the
Galadion Accord, which binds Limsa Lominsa's pirates to the Maelstrom for the
war with the Empire, and asks you to attend its signing at Aleport for the
Foreign Levy. Reyner, Storm Marshal Slafyrsyn and Hyllfyr wait with her.
At Aleport a band of pirates sells the Accord to the Garleans, who loose a
magitek vanguard on the hamlet (cutscene gc01l310). You hold the machina
back while the wounded Admiral escapes (a duty entered in place,
SimpleContentGcl10301), and once it falls Merlwyb counts the cost of the
day (cutscene gc01l320). The quest ends there.

The client script (gcl103) names the events; seed 146 holds the cast in the
Coral Tower, the Aleport trigger and the Garleans.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Answer the Admiral's summons in the Coral Tower.
SEQ_005	= 5;	-- Attend the signing of the Galadion Accord at Aleport.
SEQ_010	= 10;	-- Hold back the magitek vanguard.

-- Quest Actors
GUINCUM					= 1500199;
MERLWYB					= 1001568;
REYNER					= 1000140;	-- Commodore Reyner of the Knights of the Barracuda
EYNZAHR					= 1060024;	-- Storm Marshal (Eynzahr) Slafyrsyn
HYLLFYR					= 1000215;	-- Captain of the Bloody Executioners

-- Triggers
ALEPORT					= 1090335;

-- Places
ALEPORT_SQUARE			= {129, -1312.0, 1.9, -616.0, -2.36};	-- set down here when the machina falls

-- Rewards (the client's reward sheet row: EXP tier 6 in slot 1, seals in slot 5)
REWARD_EXP				= 1322;
REWARD_SEALS			= 1500;
COMPANY					= 1;

-- The council in the Coral Tower.
COUNCIL = {
	[HYLLFYR]	= "processEvent000_HYLLFYR",
	[EYNZAHR]	= "processEvent000_EYNZAHR",
	[REYNER]	= "processEvent000_REYNER",
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(GUINCUM, QFLAG_TALK);
		return;
	end

	if (sequence == SEQ_000) then
		quest:SetENpc(MERLWYB, QFLAG_TALK);
	elseif (sequence == SEQ_005) then
		quest:SetENpc(ALEPORT, QFLAG_PUSH, false, true);
	end
	quest:SetENpc(GUINCUM);
	for classId in pairs(COUNCIL) do
		quest:SetENpc(classId);
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
	elseif (classId == GUINCUM) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_GUINCUM");
	elseif (COUNCIL[classId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, COUNCIL[classId]);
	elseif (sequence == SEQ_000 and classId == MERLWYB) then
		-- the Galadion Accord, and a seat at its signing
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000");
		quest:StartSequence(SEQ_005);
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onPush(player, quest, npc)
	if (npc:GetActorClassId() == ALEPORT and quest:getSequence() == SEQ_005 and player:GetDirector() == nil) then
		-- the betrayal and the machina (false: fade back in where you stand)
		callClientFunction(player, "delegateEvent", player, quest, "processEvent005_NQ", false);
		quest:StartSequence(SEQ_010);
		startGcl103Content(player, quest);
		return;
	end
	player:EndEvent();
end

-- The magitek vanguard, a duty entered in place (spawnType 0x16). Its
-- director (QuestDirectorGcl10301) plays the aftermath and closes the quest
-- once the machina falls.
function startGcl103Content(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Gcl10301", "SimpleContentGcl10301", "Quest/SimpleQuestBattle/QuestDirectorGcl10301");
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

-- The machina is down: the aftermath, then the Maelstrom's thanks.
function finishGcl103(player, quest)
	callClientFunction(player, "delegateEvent", player, quest, "processEvent015_NQ");
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
