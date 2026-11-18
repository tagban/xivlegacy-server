require ("global")
require ("quest")
require ("modifiers")

--[[

Quest Script

Name:	Law and the Order
Code:	Thm306
Id:	110242
Prereq: Level 36, Thaumaturge, Thm300

Yayake tells of a coach gone over a cliff and sends you to I'llofii
(thm30610). I'llofii wants the cause found before the guild takes
vengeance (thm30620). At the wreck in Western Thanalan the overweening
thaumaturge is going through the dead's belongings (thm30630); the Echo
shows her bewitching the coachman (processEvent035/thm30640), and she
attacks (content Thm30601). Beaten, she kneels as I'llofii arrives
(thm30650); back in the Ossuary I'llofii pays 36,000 gil and 3,600
experience (thm30660).

The wreck's push circle (trigger 1090520) is on the road into the gorge,
well away from the fight, because the fight's content area keeps the
field's push circles: its first push plays thm30630 and offers the Echo,
later ones offer the Echo again (a lost fight is retried there). thm30650
crashes the client inside the content area, so a win sets you down at the
wreck and the circle plays it on your way out.

Journal: rows 152-156 of the quest journal sheet. The client has no map
markers for any Thm quest.

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Speak with I'llofii.
SEQ_010	= 10;  -- Investigate the wreck.
SEQ_020	= 20;  -- Use the Echo on your rival.
SEQ_030	= 30;  -- Defeat your rival.
SEQ_040	= 40;  -- Return to I'llofii.

-- Actor Class Ids
ENPC_YAYAKE			= 1000846;
ENPC_ILLOFII		= 1000847;
ENPC_GOGOFU			= 1000046;
ENPC_WAWATON		= 1000648;
ENPC_TOTONO			= 1001143;
ENPC_KAMLITO_HALITO	= 1001142;
ENPC_FYRILSUNN		= 1001144;
ENPC_WRECK			= 1090520; -- push circle on the road to the wreck

-- Quest Flags
FLAG_WON			= 0;  -- the rival is beaten; thm30650 plays at the circle

REWARD_GIL	= 36000;
REWARD_EXP	= 3600;

-- The wreck in Western Thanalan (cut coordinates, ground heights from the
-- client's collision mesh): where the fight starts and you are set down.
WRECK_ZONE = 172;
WRECK = { -1849.7, 24.86, -278.6, 2.6 };

-- The guild's chatter. Yayake's and I'llofii's lines name them; the rest
-- follow Thm300's hall order.
TALKS = {
	[SEQ_000] = {
		[ENPC_YAYAKE] = "processEvent010_2",
		[ENPC_GOGOFU] = "processEvent010_3",
		[ENPC_WAWATON] = "processEvent010_4",
		[ENPC_TOTONO] = "processEvent010_5",
		[ENPC_KAMLITO_HALITO] = "processEvent010_6",
		[ENPC_FYRILSUNN] = "processEvent010_7",
	},
	[SEQ_010] = {
		[ENPC_ILLOFII] = "processEvent020_2",
		[ENPC_YAYAKE] = "processEvent020_3",
	},
	[SEQ_020] = {
		[ENPC_ILLOFII] = "processEvent020_2",
	},
	[SEQ_030] = {
		[ENPC_GOGOFU] = "processEvent040_2",
		[ENPC_WAWATON] = "processEvent040_3",
	},
	[SEQ_040] = {
		[ENPC_YAYAKE] = "processEvent050_2",
		[ENPC_GOGOFU] = "processEvent050_3",
		[ENPC_WAWATON] = "processEvent050_4",
		[ENPC_TOTONO] = "processEvent050_5",
		[ENPC_KAMLITO_HALITO] = "processEvent050_6",
		[ENPC_FYRILSUNN] = "processEvent050_7",
	},
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_YAYAKE, QFLAG_TALK);
		return;
	end
	if (TALKS[sequence] ~= nil) then
		for classId, _ in pairs(TALKS[sequence]) do
			quest:SetENpc(classId);
		end
	end
	if (sequence == SEQ_000) then
		quest:SetENpc(ENPC_ILLOFII, QFLAG_TALK);
	elseif (sequence == SEQ_010 or sequence == SEQ_020 or sequence == SEQ_030) then
		-- Open until the fight is won: a lost fight is retried here.
		quest:SetENpc(ENPC_WRECK, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_040) then
		quest:SetENpc(ENPC_ILLOFII, QFLAG_REWARD);
	end
end

local function warpTo(player, zoneId, spot)
	GetWorldManager():DoZoneChange(player, zoneId, nil, 0, 15, spot[1], spot[2], spot[3], spot[4]);
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_YAYAKE) then
		-- thm30610: the accident (1 = accepted; both answers fade in place).
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventYayakeStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and npcClassId == ENPC_ILLOFII) then
		-- thm30620: find the cause before the guild takes vengeance.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		quest:StartSequence(SEQ_010);
	elseif (seq == SEQ_040 and npcClassId == ENPC_ILLOFII) then
		-- thm30660: I'llofii's word, and the reward.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent060");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 2);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddGil(REWARD_GIL);
		player:CompleteQuest(quest);
	elseif (TALKS[seq] ~= nil and TALKS[seq][npcClassId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, TALKS[seq][npcClassId]);
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (npcClassId == ENPC_WRECK and seq == SEQ_030 and quest:GetData():GetFlag(FLAG_WON)) then
		-- thm30650: she kneels, and I'llofii arrives. It ends on an
		-- after-warp fade.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050");
		quest:StartSequence(SEQ_040);
		quest:UpdateENPCs();
		player:EndEvent();
		warpTo(player, WRECK_ZONE, WRECK);
		return;
	elseif (npcClassId == ENPC_WRECK and (seq == SEQ_010 or seq == SEQ_020 or seq == SEQ_030)) then
		if (seq == SEQ_010) then
			-- thm30630: the rival at the wreck.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
			quest:StartSequence(SEQ_020);
		end
		-- The Echo prompt (1 = look); thm30640 ends on an after-warp fade,
		-- which the move into the fight lifts.
		local look = callClientFunction(player, "delegateEvent", player, quest, "processEvent035");
		if (look == 1) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent040");
			if (quest:GetSequence() ~= SEQ_030) then
				quest:StartSequence(SEQ_030);
			end
			startThm306Fight(player, quest);
			return;
		end
		quest:UpdateENPCs();
	end
	player:EndEvent();
end

function startThm306Fight(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Thm30601", "SimpleContentThm30601", "Quest/QuestDirectorThm30601", WRECK_ZONE);
	if (contentArea == nil) then
		player:EndEvent();
		warpTo(player, WRECK_ZONE, WRECK);
		return;
	end
	local director = contentArea:GetContentDirector();
	player:AddDirector(director);
	director:StartDirector(false);
	player:KickEvent(director, "noticeEvent", true);
	player:SetLoginDirector(director);
	player:EndEvent();
	GetWorldManager():DoZoneChangeContent(player, contentArea, WRECK[1], WRECK[2], WRECK[3], WRECK[4], 16);
end

-- QuestDirectorThm30601, once the rival is down (a loss never signals the
-- director).
function finishThm306Fight(player, quest, actor)
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	quest:GetData():SetFlag(FLAG_WON);
	player:EndEvent();
	player:SendMessage(0x20, "", "Your rival is defeated.");
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	warpTo(player, WRECK_ZONE, WRECK);
end

-- SimpleContentThm30601, on a loss (pinned at 1 HP, or out of time): set
-- down at the wreck to try again.
function loseThm306Fight(player, timedOut)
	if (timedOut) then
		player:SendMessage(0x20, "", "Time has run out.");
	else
		player:SendMessage(0x20, "", "You are defeated.");
	end
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	warpTo(player, WRECK_ZONE, WRECK);
end

function getJournalMapMarkerList(player, quest)
end
