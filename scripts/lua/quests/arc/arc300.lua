require ("global")
require ("quest")
require ("modifiers")

--[[

Quest Script

Name:	The Foreboding Forest
Code:	Arc300
Id:	110161
Prereq: Level 30, Archer, Arc200

Nonolato has a letter for the knights at Owl's Nest, and Keelty is to go
with you (processEvent007). At the Owl's Nest gate (arc30010) you hand the
letter to Vairemont (arc30015); Keelty arrives asking after Siward
(arc30020) and stays behind, to meet you near the Coerthas border
(processEvent025). In the North Shroud heretics fall on you (arc30025,
then content Arc30001: a bandit archer and a thunder mage). Back in the
field the knights take the captives (arc30030, which crashes the client
if played inside the duty) and Keelty asks you to look with the Echo
(arc30040), and Nonolato hears it all (arc30050) and pays 30,000 gil and
3,000 experience.

Keelty appears only in cutscenes, so each meeting with her is a push
circle where its scene starts (seed 294), as in Arc200.

]]

-- Sequence Numbers
SEQ_005	= 5;   -- Find Keelty in the guild's back room.
SEQ_010	= 10;  -- Go to Owl's Nest.
SEQ_015	= 15;  -- Deliver the letter to Vairemont.
SEQ_020	= 20;  -- Find Keelty in Owl's Nest.
SEQ_027	= 27;  -- Meet Keelty near the Coerthas border.
SEQ_040	= 40;  -- Speak with Keelty.
SEQ_050	= 50;  -- Report to Nonolato.

-- Actor Class Ids
ENPC_NONOLATO		= 1000463;
ENPC_VAIREMONT		= 1000586;
ENPC_KEELTY_GUILD	= 1090510; -- seed 294: push circles where Keelty's scenes start
ENPC_OWL_GATE		= 1090511;
ENPC_KEELTY_OWL		= 1090512;
ENPC_BORDER_FIELD	= 1090513;
ENPC_KEELTY_FIELD	= 1090514;

-- Quest Markers (each names its scene in the client's marker index; the
-- back-room meeting has none)
MRKR_OWL_GATE		= 11016101;
MRKR_VAIREMONT		= 11016102;
MRKR_KEELTY_OWL		= 11016103;
MRKR_BORDER_FIELD	= 11016104;
MRKR_KEELTY_FIELD	= 11016106;
MRKR_NONOLATO		= 11016107;

-- Quest Flags
FLAG_SAW_CAPTIVES	= 0; -- arc30030 played at Keelty's circle

REWARD_GIL	= 30000;
REWARD_EXP	= 3000;

-- Where the after-warp scenes set you down (the arc30010-40 actor tracks,
-- heights from the client's ground mesh).
OWL_INSIDE = { 2565.7, 175.5, 1319.6, -0.52 };
OWL_KEELTY = { 2566.69, 175.72, 1313.25, 0.0 };
FIELD_FIGHT = { -1587.0, 20.7, -1909.0, 0.0 };
FIELD_CAPTIVES = { -1585.86, 21.32, -1876.49, 3.14 };
FIELD_ECHO = { -1579.04, 20.47, -1881.72, 1.57 };

TALKS_NONOLATO = {
	[SEQ_005] = "processEvent003_2",
	[SEQ_010] = "processEvent015_2",
	[SEQ_015] = "processEvent015_2",
	[SEQ_020] = "processEvent015_2",
	[SEQ_027] = "processEvent015_2",
	[SEQ_040] = "processEvent015_2",
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
		quest:SetENpc(ENPC_KEELTY_GUILD, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_NONOLATO);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_OWL_GATE, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_NONOLATO);
	elseif (sequence == SEQ_015) then
		quest:SetENpc(ENPC_VAIREMONT, QFLAG_TALK);
		quest:SetENpc(ENPC_NONOLATO);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(ENPC_KEELTY_OWL, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_VAIREMONT);
		quest:SetENpc(ENPC_NONOLATO);
	elseif (sequence == SEQ_027) then
		-- Stays open: a lost or abandoned fight is retried from here.
		quest:SetENpc(ENPC_BORDER_FIELD, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_NONOLATO);
	elseif (sequence == SEQ_040) then
		-- Stays open: declining the Echo leaves her waiting.
		quest:SetENpc(ENPC_KEELTY_FIELD, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_NONOLATO);
	elseif (sequence == SEQ_050) then
		quest:SetENpc(ENPC_NONOLATO, QFLAG_REWARD);
	end
end

local function warpTo(player, zoneId, spot)
	GetWorldManager():DoZoneChange(player, zoneId, nil, 0, 15, spot[1], spot[2], spot[3], spot[4]);
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_NONOLATO) then
		-- The letter for Owl's Nest (1 = accepted).
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventNonolatoStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (npcClassId == ENPC_VAIREMONT and seq == SEQ_015) then
		-- arc30015: the letter handed over. It ends on an after-warp fade.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent015");
		quest:StartSequence(SEQ_020);
		player:EndEvent();
		warpTo(player, 145, OWL_INSIDE);
		return;
	elseif (npcClassId == ENPC_NONOLATO and seq == SEQ_050) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 2);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddGil(REWARD_GIL);
		player:CompleteQuest(quest);
	elseif (npcClassId == ENPC_NONOLATO and TALKS_NONOLATO[seq] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, TALKS_NONOLATO[seq]);
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_005 and npcClassId == ENPC_KEELTY_GUILD) then
		-- Keelty in the back room: she'll come along.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent007");
		quest:StartSequence(SEQ_010);
	elseif (seq == SEQ_010 and npcClassId == ENPC_OWL_GATE) then
		-- arc30010: the gate of Owl's Nest, on an after-warp fade.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		quest:StartSequence(SEQ_015);
		player:EndEvent();
		warpTo(player, 145, OWL_INSIDE);
		return;
	elseif (seq == SEQ_020 and npcClassId == ENPC_KEELTY_OWL) then
		-- arc30020: Keelty arrives asking after Siward (after-warp), then
		-- her parting words (025).
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		callClientFunction(player, "delegateEvent", player, quest, "processEvent025");
		quest:StartSequence(SEQ_027);
		player:EndEvent();
		warpTo(player, 145, OWL_KEELTY);
		return;
	elseif (seq == SEQ_027 and npcClassId == ENPC_BORDER_FIELD) then
		-- arc30025: the heretics' ambush. It ends on an after-warp fade,
		-- which the move into the fight lifts.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent027");
		startArc300Fight(player, quest);
		return;
	elseif (seq == SEQ_040 and npcClassId == ENPC_KEELTY_FIELD) then
		-- Keelty asks for the Echo: 1 plays arc30040 on an after-warp
		-- fade, 0 leaves her waiting.
		if (not quest:GetData():GetFlag(FLAG_SAW_CAPTIVES)) then
			-- arc30030: the knights take the captives. It crashes the
			-- client inside the duty, so it plays here, the first time.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
			quest:GetData():SetFlag(FLAG_SAW_CAPTIVES);
		end
		local echo = callClientFunction(player, "delegateEvent", player, quest, "processEvent040");
		if (echo == 1) then
			quest:StartSequence(SEQ_050);
			player:EndEvent();
			warpTo(player, 152, FIELD_ECHO);
			return;
		end
	end
	quest:UpdateENPCs();
	player:EndEvent();
end

function startArc300Fight(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Arc30001", "SimpleContentArc30001", "Quest/QuestDirectorArc30001", 152);
	if (contentArea == nil) then
		player:EndEvent();
		warpTo(player, 152, FIELD_CAPTIVES);
		return;
	end
	local director = contentArea:GetContentDirector();
	player:AddDirector(director);
	director:StartDirector(false);
	player:KickEvent(director, "noticeEvent", true);
	player:SetLoginDirector(director);
	player:EndEvent();
	GetWorldManager():DoZoneChangeContent(player, contentArea, FIELD_FIGHT[1], FIELD_FIGHT[2], FIELD_FIGHT[3], FIELD_FIGHT[4], 16);
end

-- QuestDirectorArc30001, once the heretics are down (a loss never signals
-- the director).
function finishArc300Fight(player, quest, actor)
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	-- arc30030 (the knights take the captives) waits for Keelty's circle:
	-- played here, inside the duty, it crashes the client.
	quest:StartSequence(SEQ_040);
	player:EndEvent();
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	warpTo(player, 152, FIELD_CAPTIVES);
end

-- SimpleContentArc30001, on a loss (pinned at 1 HP, or out of time): set
-- down by the field to try again. The director runs in its own Lua state
-- and can't see it.
function loseArc300Fight(player, timedOut)
	if (timedOut) then
		player:SendMessage(0x20, "", "Time has run out.");
	else
		player:SendMessage(0x20, "", "You are defeated.");
	end
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	warpTo(player, 152, FIELD_CAPTIVES);
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_010) then
		return MRKR_OWL_GATE;
	elseif (seq == SEQ_015) then
		return MRKR_VAIREMONT;
	elseif (seq == SEQ_020) then
		return MRKR_KEELTY_OWL;
	elseif (seq == SEQ_027) then
		return MRKR_BORDER_FIELD;
	elseif (seq == SEQ_040) then
		return MRKR_KEELTY_FIELD;
	elseif (seq == SEQ_050) then
		return MRKR_NONOLATO;
	end
end
