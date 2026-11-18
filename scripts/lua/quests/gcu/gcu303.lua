require ("global")
require ("quest")

--[[

Quest Script

Name: 	A Weaver and a Mummer
Code: 	Gcu303
Id: 	111819
Prereq: Level 40, a sworn member of the Immortal Flames (company_gate in quest_offers.rs).

The Hall of Flames has ordered Sunsilk Tapestries to raise a traveling
theater company to lift the troops' spirits, and Cahernaut, cast as the hero
of "The Sword and the Stone," has never seen a battle. He sends you to the
mesa northeast of Nophica's Wells, on the route Camp Horizon patrols, to see
what a soldier sees there. Imperial scouts fall upon you (a duty entered in
place, SimpleContentGcu30301). Back at Sunsilk, Cahernaut asks what you
made of it, and your answer reshapes his play.

The client script (gcu303) names the events; seed 155 holds the mesa trigger
and the scouts.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Go to the mesa northeast of Nophica's Wells.
SEQ_010	= 10;	-- Tell Cahernaut what passed.

-- Quest Actors
CAHERNAUT				= 1000915;

-- Triggers
MESA					= 1090344;

-- Places
MESA_FOOT				= {172, -754.0, 91.3, 279.0, 2.5};	-- set down here when the scouts fall

-- Rewards (the client's reward sheet row: EXP tier 6 in slot 1, seals in slot 5)
REWARD_EXP				= 1322;
REWARD_SEALS			= 1000;
COMPANY					= 3;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(CAHERNAUT, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(CAHERNAUT);
		quest:SetENpc(MESA, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(CAHERNAUT, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();

	if (classId == CAHERNAUT and sequence == SEQ_ACCEPT) then
		-- the traveling theater, and a weaver cast as a soldier
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventCAHERNAUTStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (classId == CAHERNAUT and sequence == SEQ_000) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_000");
	elseif (classId == CAHERNAUT and sequence == SEQ_010) then
		-- what a soldier thinks of, and the script rewritten
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010");
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
	if (npc:GetActorClassId() == MESA and quest:GetSequence() == SEQ_000 and player:GetDirector() == nil) then
		startGcu303Content(player, quest);
		return;
	end
	player:EndEvent();
end

-- The scouts, a duty entered in place (spawnType 0x16). Its director
-- (QuestDirectorGcu30301) sets you back down at the mesa's foot once they fall.
function startGcu303Content(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Gcu30301", "SimpleContentGcu30301", "Quest/SimpleQuestBattle/QuestDirectorGcu30301");
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
