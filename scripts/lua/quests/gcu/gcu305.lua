require ("global")
require ("quest")

--[[

Quest Script

Name: 	Challenge Accepted
Code: 	Gcu305
Id: 	111826
Prereq: Level 50, a sworn member of the Immortal Flames (company_gate in quest_offers.rs).

The Platinum Mirage recoups its bad loans by sending defaulters into the Free
Brigade, and the defaulters keep dying. I'Paghlo suspects High Commander
Ryder, who is said to dare his men to make attempts on his life, and sends
you to the mesa south of Mythril Pit No. 8 to watch the brigade drill. You
find only Ryder's sport, the undead of those parts (a duty entered in
place, SimpleContentGcu30501), and Ryder himself, who sees through the
Mirage's game: he never killed his challengers, he pays whoever bests him.

The client script (gcu305) names the events; seed 156 holds Ryder at the
mesa, the trigger and the undead.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Go to the mesa south of Mythril Pit No. 8.
SEQ_010	= 10;	-- Speak with High Commander Ryder.

-- Quest Actors
IPAGHLO					= 1001260;
RYDER					= 1001815;

-- Triggers
MESA					= 1090345;

-- Places
MESA_FOOT				= {171, 1330.4, 258.2, -179.1, 0.0};	-- set down here, before Ryder, when the undead fall

-- Rewards (the client's reward sheet row: EXP tier 6 in slot 1, seals in slot 5)
REWARD_EXP				= 1322;
REWARD_SEALS			= 700;
COMPANY					= 3;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(IPAGHLO, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(IPAGHLO);
		quest:SetENpc(MESA, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(RYDER, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();

	if (classId == IPAGHLO and sequence == SEQ_ACCEPT) then
		-- the defaulters sent to the Free Brigade, and Ryder's challenge
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventI_PAGHLOStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (classId == IPAGHLO and sequence == SEQ_000) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
	elseif (classId == RYDER and sequence == SEQ_010) then
		-- the Mirage's game, and the reward for besting him
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
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
		startGcu305Content(player, quest);
		return;
	end
	player:EndEvent();
end

-- The undead, a duty entered in place (spawnType 0x16). Its director
-- (QuestDirectorGcu30501) sets you down before Ryder once they fall.
function startGcu305Content(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Gcu30501", "SimpleContentGcu30501", "Quest/SimpleQuestBattle/QuestDirectorGcu30501");
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
