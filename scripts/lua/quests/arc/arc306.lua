require ("global")
require ("quest")
require ("modifiers")

--[[

Quest Script

Name:	There Can Be Only One
Code:	Arc306
Id:	110162
Prereq: Level 36, Archer, Arc300

Keelty hasn't come back, and Nonolato fears someone is hunting her. The
other archers say where she was last seen; in the Central Shroud west of
Humblehearth you find her wounded (arc30610) and she sends you running
back towards Sorrel Haven. Going back for her (arc30620), you find her
cornered by Siward and his yarzons (content Arc30601). Siward beaten, he
taunts Keelty and leaves, and a conjurer takes her in (arc30630). In the
Quiver's Hold Keelty tells you who Siward was (arc30640), and Nonolato
(arc30650) pays 36,000 gil and 3,600 experience.

Keelty appears only in cutscenes: the meeting in the wood is a push circle
(1090518) and her talk in the Quiver's Hold uses Arc300's back-room circle
(1090510).

Journal: steps 171-176 of the quest journal sheet.

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Ask the archers, and find Keelty.
SEQ_010	= 10;  -- Sent away; go back for her.
SEQ_020	= 20;  -- Save Keelty from her assassin (back in the wood: it was lost).
SEQ_040	= 40;  -- Back to the Quiver's Hold.
SEQ_050	= 50;  -- Nonolato has your reward.

-- Actor Class Ids
ENPC_NONOLATO		= 1000463;
ENPC_BUBUKU			= 1000625;
ENPC_ODHINEK		= 1000829;
ENPC_GEORJEAUX		= 1000830;
ENPC_MIANNE			= 1000832;
ENPC_CHLOE			= 1001175;
ENPC_KEELTY_GUILD	= 1090510; -- Arc300's push circle in the guild's back room
ENPC_KEELTY_WOOD	= 1090518; -- push circle where Keelty is found

-- Quest Markers (each names its scene in the client's marker index)
MRKR_FIND_KEELTY	= 11016201;
MRKR_GO_BACK		= 11016202;
MRKR_ASSASSIN		= 11016203;
MRKR_CONFESSION		= 11016204;
MRKR_NONOLATO		= 11016205;

REWARD_GIL	= 36000;
REWARD_EXP	= 3600;

-- The Central Shroud (ZAM's map (26, 33), heights from the client's ground
-- mesh). FIGHT is where the fight starts and where you are set down after
-- it; SORREL_HAVEN is by the aetheryte, where Keelty sends you.
WOOD_ZONE = 150;
FIGHT = { -444.0, 3.47, -448.0, 1.57 };
SORREL_HAVEN = { -280.0, -21.5, -52.0, 0.0 };
-- The Quiver's Hold, in front of Nonolato.
GUILD_ZONE = 206;
GUILD_HALL = { 234.5, 12.0, -1273.0, -0.37 };

-- What the archers say between steps. The client script names no speaker;
-- these follow the lines' content. Cassandra is left out: her shop greeting
-- runs instead of a quest line.
TALKS = {
	[SEQ_000] = {
		[ENPC_NONOLATO] = "processEvent005_2",
		[ENPC_MIANNE] = "processEvent005_3",
		[ENPC_GEORJEAUX] = "processEvent005_4",
		[ENPC_BUBUKU] = "processEvent005_5",
		[ENPC_ODHINEK] = "processEvent005_7",
		[ENPC_CHLOE] = "processEvent005_8",
	},
	[SEQ_010] = {
		[ENPC_NONOLATO] = "processEvent005_2",
		[ENPC_MIANNE] = "processEvent010_2",
	},
	[SEQ_020] = {
		[ENPC_NONOLATO] = "processEvent005_2",
		[ENPC_MIANNE] = "processEvent010_2",
	},
	[SEQ_040] = {
		[ENPC_MIANNE] = "processEvent040_2",
		[ENPC_GEORJEAUX] = "processEvent040_3",
		[ENPC_BUBUKU] = "processEvent040_4",
		[ENPC_ODHINEK] = "processEvent040_5",
		[ENPC_CHLOE] = "processEvent040_7",
		[ENPC_NONOLATO] = "processEvent040_8",
	},
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_NONOLATO, QFLAG_TALK);
		return;
	end
	if (TALKS[sequence] ~= nil) then
		for classId, _ in pairs(TALKS[sequence]) do
			quest:SetENpc(classId);
		end
	end
	if (sequence == SEQ_000 or sequence == SEQ_010 or sequence == SEQ_020) then
		-- SEQ_020 keeps it open: a lost fight is retried from here.
		quest:SetENpc(ENPC_KEELTY_WOOD, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_040) then
		quest:SetENpc(ENPC_KEELTY_GUILD, QFLAG_PUSH, false, true);
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
		-- Find Keelty (1 = accepted).
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventNonolatoStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_050 and npcClassId == ENPC_NONOLATO) then
		-- arc30650: the report, and payment.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050");
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

	if (npcClassId == ENPC_KEELTY_WOOD and seq == SEQ_000) then
		-- arc30610: Keelty, wounded, sends you running. It ends on an
		-- after-warp fade, by the Sorrel Haven aetheryte.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		quest:StartSequence(SEQ_010);
		player:EndEvent();
		warpTo(player, WOOD_ZONE, SORREL_HAVEN);
		return;
	elseif (npcClassId == ENPC_KEELTY_WOOD and (seq == SEQ_010 or seq == SEQ_020)) then
		-- arc30620: Keelty cornered by Siward (again, after a loss). It ends
		-- on an after-warp fade, which the move into the fight lifts.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		if (seq == SEQ_010) then
			quest:StartSequence(SEQ_020);
		end
		startArc306Fight(player, quest);
		return;
	elseif (npcClassId == ENPC_KEELTY_GUILD and seq == SEQ_040) then
		-- arc30640: Keelty tells of Siward. It ends on an after-warp fade.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent040");
		quest:StartSequence(SEQ_050);
		player:EndEvent();
		warpTo(player, GUILD_ZONE, GUILD_HALL);
		return;
	end
	player:EndEvent();
end

function startArc306Fight(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Arc30601", "SimpleContentArc30601", "Quest/QuestDirectorArc30601", WOOD_ZONE);
	if (contentArea == nil) then
		player:EndEvent();
		warpTo(player, WOOD_ZONE, FIGHT);
		return;
	end
	local director = contentArea:GetContentDirector();
	player:AddDirector(director);
	director:StartDirector(false);
	player:KickEvent(director, "noticeEvent", true);
	player:SetLoginDirector(director);
	player:EndEvent();
	GetWorldManager():DoZoneChangeContent(player, contentArea, FIGHT[1], FIGHT[2], FIGHT[3], FIGHT[4], 16);
end

-- QuestDirectorArc30601, once Siward is down (a loss never signals the
-- director).
function finishArc306Fight(player, quest, actor)
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	-- arc30630: Siward's parting words, and the conjurer. It ends on an
	-- after-warp fade.
	callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
	quest:StartSequence(SEQ_040);
	player:EndEvent();
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	warpTo(player, WOOD_ZONE, FIGHT);
end

-- SimpleContentArc30601, on a loss (pinned at 1 HP, or out of time): set
-- down in the wood to try again. The director runs in its own Lua state
-- and can't see it.
function loseArc306Fight(player, timedOut)
	if (timedOut) then
		player:SendMessage(0x20, "", "Time has run out.");
	else
		player:SendMessage(0x20, "", "You are defeated.");
	end
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	warpTo(player, WOOD_ZONE, FIGHT);
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_000) then
		return MRKR_FIND_KEELTY;
	elseif (seq == SEQ_010) then
		return MRKR_GO_BACK;
	elseif (seq == SEQ_020) then
		return MRKR_ASSASSIN;
	elseif (seq == SEQ_040) then
		return MRKR_CONFESSION;
	elseif (seq == SEQ_050) then
		return MRKR_NONOLATO;
	end
end
