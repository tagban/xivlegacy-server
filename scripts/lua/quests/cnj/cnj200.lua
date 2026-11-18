require ("global")
require ("quest")
require ("modifiers")

--[[

Quest Script

Name:	Dendrological Duties
Code:	Cnj200
Id:	110260
Prereq: Level 20, Conjurer

The Conjurers' Guild's welcome. Soileine takes you into the order (cnj20010
plays inside her offer) and sends you to Brother Telent, who has heard
from the trees that a pack of coywolves must be put down east of the Blue
Badger Gate (processEvent015). You fight them in a clearing of withered
trees (a private fight, content Cnj20001); Brother Morys finds you there
(cnj20020). Telent hears you out (cnj20030) and Soileine pays you
(processEvent040).

]]

-- Sequence Numbers
SEQ_010	= 10;  -- Speak with Brother Telent.
SEQ_015	= 15;  -- Put down the coywolves east of the Blue Badger Gate.
SEQ_020	= 20;  -- Report to Brother Telent.
SEQ_030	= 30;  -- Collect your pay from Soileine.

-- Actor Class Ids
ENPC_SOILEINE		= 1000234;
ENPC_TELENT			= 1000504; -- seed 199: given a spawn in Stillglade Fane
ENPC_CLEARING		= 1090507; -- seed 199: push circle at the withered trees

-- Quest Markers
MRKR_TELENT			= 11026001;
MRKR_CLEARING		= 11026002;
MRKR_SOILEINE		= 11026003;

REWARD_GIL	= 20000;
REWARD_EXP	= 2000;

-- Where the fight is fought and where cnj20020 leaves you (both from the
-- scene's own tracks).
CLEARING_FIGHT = { 718.5, 31.8, -843.5, 0.0 };
CLEARING_GROUND = { 718.9, 31.8, -844.1, 0.0 };

-- What Soileine and Telent say between steps; the other guild lines name
-- no speaker.
TALKS_SOILEINE = {
	[SEQ_010] = "processEvent010_2",
	[SEQ_020] = "processEvent020_2",
};
TALKS_TELENT = {
	[SEQ_015] = "processEvent015_2",
	[SEQ_030] = "processEvent030_2",
};

function onStart(player, quest)
	quest:StartSequence(SEQ_010);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_SOILEINE, QFLAG_TALK);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_TELENT, QFLAG_TALK);
		quest:SetENpc(ENPC_SOILEINE);
	elseif (sequence == SEQ_015) then
		-- Stays open: a lost or abandoned fight is retried from here.
		quest:SetENpc(ENPC_CLEARING, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_TELENT);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(ENPC_TELENT, QFLAG_TALK);
		quest:SetENpc(ENPC_SOILEINE);
	elseif (sequence == SEQ_030) then
		quest:SetENpc(ENPC_SOILEINE, QFLAG_REWARD);
		quest:SetENpc(ENPC_TELENT);
	end
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_SOILEINE) then
		-- The offer plays cnj20010 when you accept.
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventSoileineStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (npcClassId == ENPC_TELENT) then
		if (seq == SEQ_010) then
			-- The trees' bargain: the coywolves east of the gate.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent015");
			quest:StartSequence(SEQ_015);
		elseif (seq == SEQ_020) then
			-- cnj20030: Telent hears you out.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
			quest:StartSequence(SEQ_030);
		elseif (TALKS_TELENT[seq] ~= nil) then
			callClientFunction(player, "delegateEvent", player, quest, TALKS_TELENT[seq]);
		end
	elseif (npcClassId == ENPC_SOILEINE) then
		if (seq == SEQ_030) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent040");
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 2);
			player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
			player:AddGil(REWARD_GIL);
			player:CompleteQuest(quest);
		elseif (TALKS_SOILEINE[seq] ~= nil) then
			callClientFunction(player, "delegateEvent", player, quest, TALKS_SOILEINE[seq]);
		end
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_015 and npcClassId == ENPC_CLEARING) then
		startCnj200Fight(player, quest);
		return;
	end
	quest:UpdateENPCs();
	player:EndEvent();
end

function startCnj200Fight(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Cnj20001", "SimpleContentCnj20001", "Quest/QuestDirectorCnj20001", 150);
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
	GetWorldManager():DoZoneChangeContent(player, contentArea, CLEARING_FIGHT[1], CLEARING_FIGHT[2], CLEARING_FIGHT[3], CLEARING_FIGHT[4], 16);
end

-- QuestDirectorCnj20001, once the coywolves are down (a loss never signals
-- the director).
function finishCnj200Fight(player, quest, actor)
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	-- cnj20020: Brother Morys. It ends on an after-warp fade.
	callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
	quest:StartSequence(SEQ_020);
	player:EndEvent();
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	GetWorldManager():DoZoneChange(player, 150, nil, 0, 15, CLEARING_GROUND[1], CLEARING_GROUND[2], CLEARING_GROUND[3], CLEARING_GROUND[4]);
end

-- SimpleContentCnj20001, on a loss: set down in the clearing to try again.
-- The director runs in its own Lua state and can't see it.
function loseCnj200Fight(player)
	player:SendMessage(0x20, "", "You are defeated.");
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	GetWorldManager():DoZoneChange(player, 150, nil, 0, 15, CLEARING_GROUND[1], CLEARING_GROUND[2], CLEARING_GROUND[3], CLEARING_GROUND[4]);
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_010 or seq == SEQ_020) then
		return MRKR_TELENT;
	elseif (seq == SEQ_015) then
		return MRKR_CLEARING;
	elseif (seq == SEQ_030) then
		return MRKR_SOILEINE;
	end
end
