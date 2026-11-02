require ("global")
require ("quest")
require ("modifiers")

--[[

Quest Script

Name:	Filling the Quiver
Code:	Arc200
Id:	110160
Prereq: Level 20, Archer

The Archers' Guild's welcome. Nonolato signs you on with the Gods' Quiver
and pairs you with Keelty, who waits inside (arc20010) and sends you ahead
to Camp Emerald Moss. At the camp (arc20020) she splits off to patrol;
an Ixal waits on your side of the wood (arc20030, then a private fight,
content Arc20001). With the Ixal driven off, Keelty is missing: you find
her a short way off (arc20040), and Nonolato hears you out and pays you
(processEvent050).

]]

-- Sequence Numbers
SEQ_005	= 5;   -- Find Keelty inside the guild.
SEQ_010	= 10;  -- Meet Keelty at Camp Emerald Moss.
SEQ_020	= 20;  -- Patrol: the Ixal.
SEQ_030	= 30;  -- Find Keelty.
SEQ_040	= 40;  -- Report to Nonolato.

-- Actor Class Ids
ENPC_NONOLATO		= 1000463;
ENPC_GUILD_INSIDE	= 1090502; -- seed 197: push circles (Keelty is cutscene-only)
ENPC_EMERALD_MOSS	= 1090503;
ENPC_IXAL_GROUND	= 1090504;
ENPC_KEELTY_FOUND	= 1090505;

-- Quest Markers
MRKR_GUILD_INSIDE	= 11016001;
MRKR_EMERALD_MOSS	= 11016002;
MRKR_IXAL_GROUND	= 11016003;
MRKR_KEELTY_FOUND	= 11016004;
MRKR_NONOLATO		= 11016005;

REWARD_GIL	= 20000;
REWARD_EXP	= 2000;

-- Where each after-warp scene leaves you (taken from the scenes), and
-- where the fight is fought.
GUILD_INSIDE = { 237.7, 12.0, -1278.0, 0.0 };
IXAL_FIGHT = { -1580.0, 20.3, -1896.0, -2.4 };
IXAL_GROUND = { -1572.1, 20.1, -1893.2, -2.4 };
KEELTY_FOUND = { -1440.0, 20.0, -1780.0, 0.0 };

-- Nonolato's word at each step; the other guild lines name no speaker.
TALKS_NONOLATO = {
	[SEQ_005] = "processEvent005_2",
	[SEQ_010] = "processEvent010_2",
	[SEQ_030] = "processEvent030_2",
};

function onStart(player, quest)
	quest:StartSequence(SEQ_005);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_NONOLATO, QFLAG_TALK);
	elseif (sequence == SEQ_005) then
		quest:SetENpc(ENPC_GUILD_INSIDE, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_NONOLATO);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_EMERALD_MOSS, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_NONOLATO);
	elseif (sequence == SEQ_020) then
		-- Stays open: a lost or abandoned fight is retried from here.
		quest:SetENpc(ENPC_IXAL_GROUND, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_030) then
		quest:SetENpc(ENPC_KEELTY_FOUND, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_NONOLATO);
	elseif (sequence == SEQ_040) then
		quest:SetENpc(ENPC_NONOLATO, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_NONOLATO) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventNonolatoStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (npcClassId == ENPC_NONOLATO) then
		if (seq == SEQ_040) then
			-- She asks what the patrol taught you, then pays out.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent050");
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 2);
			player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
			player:AddGil(REWARD_GIL);
			player:CompleteQuest(quest);
		elseif (TALKS_NONOLATO[seq] ~= nil) then
			callClientFunction(player, "delegateEvent", player, quest, TALKS_NONOLATO[seq]);
		end
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_005 and npcClassId == ENPC_GUILD_INSIDE) then
		-- arc20010: Keelty. It ends on an after-warp fade, lifted by a warp
		-- back to the same spot.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		quest:StartSequence(SEQ_010);
		player:EndEvent();
		GetWorldManager():DoZoneChange(player, 206, nil, 0, 15, GUILD_INSIDE[1], GUILD_INSIDE[2], GUILD_INSIDE[3], GUILD_INSIDE[4]);
		return;
	elseif (seq == SEQ_010 and npcClassId == ENPC_EMERALD_MOSS) then
		-- arc20020: Keelty splits off to patrol.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		quest:StartSequence(SEQ_020);
	elseif (seq == SEQ_020 and npcClassId == ENPC_IXAL_GROUND) then
		-- arc20030: the Ixal. It ends on an after-warp fade, which the warp
		-- into the fight lifts.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
		startArc200Fight(player, quest);
		return;
	elseif (seq == SEQ_030 and npcClassId == ENPC_KEELTY_FOUND) then
		-- arc20040: Keelty, tangled in the roots. After-warp, as above.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent040");
		quest:StartSequence(SEQ_040);
		player:EndEvent();
		GetWorldManager():DoZoneChange(player, 152, nil, 0, 15, KEELTY_FOUND[1], KEELTY_FOUND[2], KEELTY_FOUND[3], KEELTY_FOUND[4]);
		return;
	end
	quest:UpdateENPCs();
	player:EndEvent();
end

function startArc200Fight(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Arc20001", "SimpleContentArc20001", "Quest/QuestDirectorArc20001", 152);
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
	GetWorldManager():DoZoneChangeContent(player, contentArea, IXAL_FIGHT[1], IXAL_FIGHT[2], IXAL_FIGHT[3], IXAL_FIGHT[4], 16);
end

-- QuestDirectorArc20001, once the Ixal and the yarzons are down (a loss
-- never signals the director).
function finishArc200Fight(player, quest, actor)
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	quest:StartSequence(SEQ_030);
	player:EndEvent();
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	GetWorldManager():DoZoneChange(player, 152, nil, 0, 15, IXAL_GROUND[1], IXAL_GROUND[2], IXAL_GROUND[3], IXAL_GROUND[4]);
end

-- SimpleContentArc20001, on a loss: set down where the fight began to try
-- again. The director runs in its own Lua state and can't see it.
function loseArc200Fight(player)
	player:SendMessage(0x20, "", "You are defeated.");
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	GetWorldManager():DoZoneChange(player, 152, nil, 0, 15, IXAL_GROUND[1], IXAL_GROUND[2], IXAL_GROUND[3], IXAL_GROUND[4]);
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_005) then
		return MRKR_GUILD_INSIDE;
	elseif (seq == SEQ_010) then
		return MRKR_EMERALD_MOSS;
	elseif (seq == SEQ_020) then
		return MRKR_IXAL_GROUND;
	elseif (seq == SEQ_030) then
		return MRKR_KEELTY_FOUND;
	elseif (seq == SEQ_040) then
		return MRKR_NONOLATO;
	end
end
