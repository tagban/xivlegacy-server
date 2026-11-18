require ("global")
require ("quest")
require ("modifiers")

--[[

Quest Script

Name:	A Wailing Welcome
Code:	Lnc200
Id:	110180
Prereq: Level 20, Lancer

The Lancers' Guild's welcome. Willelda enlists you in the Wood Wailers and
sends you to J'moldva within, who hands you your first ranging (lnc20010):
the botanists' harvests are overrun with chigoes. At Lifemend Stump in the
Central Shroud you cull them (a private fight, content Lnc20001), and the
swarm draws something worse (lnc20020). J'moldva takes your report
(lnc20030) and sends you back to Willelda for your pay (processEvent040).

]]

-- Sequence Numbers
SEQ_005	= 5;   -- Speak with J'moldva.
SEQ_010	= 10;  -- Cull the chigoes at Lifemend Stump.
SEQ_020	= 20;  -- Report to J'moldva.
SEQ_030	= 30;  -- Collect your pay from Willelda.

-- Actor Class Ids
ENPC_WILLELDA		= 1000242;
ENPC_JMOLDVA		= 1000599;
ENPC_LIFEMEND_STUMP	= 1090506; -- seed 198: push circle at the infested stump

-- Quest Markers
MRKR_JMOLDVA		= 11018001;
MRKR_LIFEMEND_STUMP	= 11018002;
MRKR_WILLELDA		= 11018003;

REWARD_GIL	= 20000;
REWARD_EXP	= 2000;

-- Where the cull is fought and where lnc20020 leaves you (both from the
-- scene's own tracks).
STUMP_FIGHT = { -640.5, 4.1, -993.2, 0.0 };
STUMP_GROUND = { -637.6, 4.2, -994.7, 0.0 };

-- What Willelda and J'moldva say between steps; the other guild lines
-- name no speaker.
TALKS_WILLELDA = {
	[SEQ_005] = "processEvent005_2",
	[SEQ_020] = "processEvent020_2",
};
TALKS_JMOLDVA = {
	[SEQ_010] = "processEvent010_2",
	[SEQ_030] = "processEvent030_3",
};

function onStart(player, quest)
	quest:StartSequence(SEQ_005);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_WILLELDA, QFLAG_TALK);
	elseif (sequence == SEQ_005) then
		quest:SetENpc(ENPC_JMOLDVA, QFLAG_TALK);
		quest:SetENpc(ENPC_WILLELDA);
	elseif (sequence == SEQ_010) then
		-- Stays open: a lost or abandoned cull is retried from here.
		quest:SetENpc(ENPC_LIFEMEND_STUMP, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_JMOLDVA);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(ENPC_JMOLDVA, QFLAG_TALK);
		quest:SetENpc(ENPC_WILLELDA);
	elseif (sequence == SEQ_030) then
		quest:SetENpc(ENPC_WILLELDA, QFLAG_REWARD);
		quest:SetENpc(ENPC_JMOLDVA);
	end
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_WILLELDA) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventWilleldaStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (npcClassId == ENPC_JMOLDVA) then
		if (seq == SEQ_005) then
			-- lnc20010: the chigoes and the masks.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
			quest:StartSequence(SEQ_010);
		elseif (seq == SEQ_020) then
			-- lnc20030: the report.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
			quest:StartSequence(SEQ_030);
		elseif (TALKS_JMOLDVA[seq] ~= nil) then
			callClientFunction(player, "delegateEvent", player, quest, TALKS_JMOLDVA[seq]);
		end
	elseif (npcClassId == ENPC_WILLELDA) then
		if (seq == SEQ_030) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent040");
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 2);
			player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
			player:AddGil(REWARD_GIL);
			player:CompleteQuest(quest);
		elseif (TALKS_WILLELDA[seq] ~= nil) then
			callClientFunction(player, "delegateEvent", player, quest, TALKS_WILLELDA[seq]);
		end
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_010 and npcClassId == ENPC_LIFEMEND_STUMP) then
		startLnc200Cull(player, quest);
		return;
	end
	quest:UpdateENPCs();
	player:EndEvent();
end

function startLnc200Cull(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Lnc20001", "SimpleContentLnc20001", "Quest/QuestDirectorLnc20001", 150);
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
	GetWorldManager():DoZoneChangeContent(player, contentArea, STUMP_FIGHT[1], STUMP_FIGHT[2], STUMP_FIGHT[3], STUMP_FIGHT[4], 16);
end

-- QuestDirectorLnc20001, once the chigoes are down (a loss never signals
-- the director).
function finishLnc200Cull(player, quest, actor)
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	-- lnc20020: the swarm draws an attack. It ends on an after-warp fade.
	callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
	quest:StartSequence(SEQ_020);
	player:EndEvent();
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	GetWorldManager():DoZoneChange(player, 150, nil, 0, 15, STUMP_GROUND[1], STUMP_GROUND[2], STUMP_GROUND[3], STUMP_GROUND[4]);
end

-- SimpleContentLnc20001, on a loss: set down at the stump to try again. The
-- director runs in its own Lua state and can't see it.
function loseLnc200Cull(player)
	player:SendMessage(0x20, "", "You are defeated.");
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	GetWorldManager():DoZoneChange(player, 150, nil, 0, 15, STUMP_GROUND[1], STUMP_GROUND[2], STUMP_GROUND[3], STUMP_GROUND[4]);
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_005 or seq == SEQ_020) then
		return MRKR_JMOLDVA;
	elseif (seq == SEQ_010) then
		return MRKR_LIFEMEND_STUMP;
	elseif (seq == SEQ_030) then
		return MRKR_WILLELDA;
	end
end
