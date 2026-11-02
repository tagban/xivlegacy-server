require ("global")
require ("quest")
require ("modifiers")

--[[

Quest Script

Name:	All Bark and No Bite
Code:	Gla200
Id:	110080
Prereq: Level 20, Gladiator

The Gladiators' Guild's welcome. Lulutsu of the Coliseum talks up the
bloodsands and signs you on to help weed the weak out of the selections for
the next tourney. Through the doors at the back of the guild hall
(gla20010) an Ala Mhigan challenger waits on the sands: beat him (content
Gla20001, gla20020 after) and report to Lulutsu (gla20030) for an iron
shortsword, 20,000 gil and 2,000 experience.

Journal: steps 28-30 of the quest journal sheet.

]]

-- Sequence Numbers
SEQ_005	= 5;   -- Head for the Coliseum (the doors at the back of the hall).
SEQ_010	= 10;  -- Your challenger waits on the sands. Finish him!
SEQ_020	= 20;  -- Report to Lulutsu.

-- Actor Class Ids
ENPC_LULUTSU		= 1000863;
ENPC_COYNACH		= 1000631;
ENPC_LYNGWAEK		= 1000647;
ENPC_JAJANZO		= 1000654;
ENPC_UBOKHN			= 1000668;
ENPC_YOYOBINA		= 1000927;
ENPC_SINGLETON		= 1001445;
ENPC_VANNES			= 1001464;
ENPC_TATASHA		= 1001465;
ENPC_ARENA_DOORS	= 1090500; -- seed 195: push circle at the doors behind Yoyobina

-- Quest Markers
MRKR_ARENA_DOORS	= 11008001;
MRKR_CHALLENGER		= 11008002;
MRKR_LULUTSU		= 11008003;

ITEM_IRON_SHORTSWORD	= 4030203;
REWARD_GIL				= 20000;
REWARD_EXP				= 2000;

-- Where the bout is fought (the man0u1/Pgl200 arena spot) and where you are
-- set down afterwards, in front of the guild counter.
ARENA = { -209.9, 192.0, 146.4, 0.8 };
GUILD_HALL = { -190.5, 195.0, 184.5, 3.0 };

-- The guild's word for a new hand before the bout (005_2..10) and after it
-- (020_3..10; 020_2 belongs to the beaten challenger, who isn't in the
-- hall). The speakers are matched to the lines by voice; the client
-- script doesn't name them.
TALKS_005 = {
	[ENPC_LULUTSU] = "processEvent005_2",
	[ENPC_JAJANZO] = "processEvent005_3",
	[ENPC_COYNACH] = "processEvent005_4",
	[ENPC_SINGLETON] = "processEvent005_5",
	[ENPC_LYNGWAEK] = "processEvent005_6",
	[ENPC_VANNES] = "processEvent005_7",
	[ENPC_YOYOBINA] = "processEvent005_8",
	[ENPC_TATASHA] = "processEvent005_9",
	[ENPC_UBOKHN] = "processEvent005_10",
};
TALKS_020 = {
	[ENPC_JAJANZO] = "processEvent020_3",
	[ENPC_COYNACH] = "processEvent020_4",
	[ENPC_SINGLETON] = "processEvent020_5",
	[ENPC_LYNGWAEK] = "processEvent020_6",
	[ENPC_VANNES] = "processEvent020_7",
	[ENPC_YOYOBINA] = "processEvent020_8",
	[ENPC_TATASHA] = "processEvent020_9",
	[ENPC_UBOKHN] = "processEvent020_10",
};

function onStart(player, quest)
	quest:StartSequence(SEQ_005);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_LULUTSU, QFLAG_TALK);
	elseif (sequence == SEQ_005 or sequence == SEQ_010) then
		-- SEQ_010 keeps the doors open: a lost or abandoned bout is retried
		-- from the hall.
		quest:SetENpc(ENPC_ARENA_DOORS, QFLAG_PUSH, false, true);
		for classId, _ in pairs(TALKS_005) do
			quest:SetENpc(classId);
		end
	elseif (sequence == SEQ_020) then
		quest:SetENpc(ENPC_LULUTSU, QFLAG_REWARD);
		for classId, _ in pairs(TALKS_020) do
			quest:SetENpc(classId);
		end
	end
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_LULUTSU) then
		-- The guild sign-up offer.
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventLulutsuStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_005 or seq == SEQ_010) then
		if (TALKS_005[npcClassId] ~= nil) then
			callClientFunction(player, "delegateEvent", player, quest, TALKS_005[npcClassId]);
		end
	elseif (seq == SEQ_020) then
		if (npcClassId == ENPC_LULUTSU) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 2);
			player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
			player:GetItemPackage(INVENTORY_NORMAL):AddItem(ITEM_IRON_SHORTSWORD, 1, 1);
			player:AddGil(REWARD_GIL);
			player:CompleteQuest(quest);
		elseif (TALKS_020[npcClassId] ~= nil) then
			callClientFunction(player, "delegateEvent", player, quest, TALKS_020[npcClassId]);
		end
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (npcClassId == ENPC_ARENA_DOORS and (seq == SEQ_005 or seq == SEQ_010)) then
		if (seq == SEQ_005) then
			-- gla20010: out onto the sands. It ends on an after-warp fade,
			-- which the warp into the bout lifts.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
			quest:StartSequence(SEQ_010);
		end
		startGla200Bout(player, quest);
		return;
	end
	player:EndEvent();
end

function startGla200Bout(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Gla20001", "SimpleContentGla20001", "Quest/QuestDirectorGla20001", 209);
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
	GetWorldManager():DoZoneChangeContent(player, contentArea, ARENA[1], ARENA[2], ARENA[3], ARENA[4], 16);
end

-- QuestDirectorGla20001, after a win (a loss never signals the director).
function finishGla200Bout(player, quest, actor)
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	-- gla20020: the challenger goes down. It ends on an after-warp fade.
	callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
	quest:StartSequence(SEQ_020);
	player:EndEvent();
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	GetWorldManager():DoZoneChange(player, 209, nil, 0, 15, GUILD_HALL[1], GUILD_HALL[2], GUILD_HALL[3], GUILD_HALL[4]);
end

-- SimpleContentGla20001, on a loss: back to the hall to try again. The
-- content ends it itself; the director runs in its own Lua state and can't
-- see what happened.
function loseGla200Bout(player)
	player:SendMessage(0x20, "", "You are defeated.");
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	GetWorldManager():DoZoneChange(player, 209, nil, 0, 15, GUILD_HALL[1], GUILD_HALL[2], GUILD_HALL[3], GUILD_HALL[4]);
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_005) then
		return MRKR_ARENA_DOORS;
	elseif (seq == SEQ_010) then
		return MRKR_CHALLENGER;
	elseif (seq == SEQ_020) then
		return MRKR_LULUTSU;
	end
end
