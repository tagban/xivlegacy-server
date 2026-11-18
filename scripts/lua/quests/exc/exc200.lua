require ("global")
require ("quest")
require ("modifiers")

--[[

Quest Script

Name:	Bloody Baptism
Code:	Exc200
Id:	110100
Prereq: Level 20, Marauder

The Marauders' Guild's welcome. Waekbyrt signs you on with the Bloody
Executioners aboard the Astalicia (exc20010) and sends you to Nunuba, who
explains the Trident and sends you to Swiftperch Tower near Aleport to cull
its lemmings. Arriving at the tower (exc20020) starts a private hunt
(content Exc20001); clearing it (exc20030) sends you back to the Astalicia,
where Waekbyrt's drunk Rostnsthal turns up (exc20040) and the two pay you
off (exc20050).

Journal: steps 115-117 of the quest journal sheet.

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Speak with Nunuba.
SEQ_010	= 10;  -- Cull the lemmings at Swiftperch Tower.
SEQ_020	= 20;  -- Report to Waekbyrt aboard the Astalicia.
SEQ_030	= 30;  -- Report to Nunuba.

-- Actor Class Ids
ENPC_WAEKBYRT		= 1000003;
ENPC_NUNUBA			= 1000004;
ENPC_CHICHIROON		= 1000217;
ENPC_JOJOROON		= 1000220;
ENPC_MIMIROON		= 1000221;
ENPC_TOWER			= 1090501; -- seed 196: push circle at the foot of Swiftperch Tower

-- Quest Markers
MRKR_NUNUBA		= 11010001;
MRKR_TOWER		= 11010002;
MRKR_WAEKBYRT	= 11010003;
MRKR_NUNUBA2	= 11010004;

REWARD_GIL	= 20000;
REWARD_EXP	= 2000;

-- Where the hunt is fought (below the tower, where exc20020 shows the
-- lemmings) and where you are set down when it ends, on the path up.
HUNT = { -790.4, 45.4, -680.9, 2.4 };
TOWER_OUTSIDE = { -797.8, 49.2, -669.7, 2.4 };

-- The crew's word for a new hand (010_2..18; only the speakers the lines
-- name or place for certain are wired: Waekbyrt's drunk, and the three
-- Lalafell lookouts who speak in their own names). 015_3 is Nunuba's
-- reminder once she has sent you off.
TALKS_010 = {
	[ENPC_WAEKBYRT] = "processEvent010_2",
	[ENPC_CHICHIROON] = "processEvent010_16",
	[ENPC_MIMIROON] = "processEvent010_17",
	[ENPC_JOJOROON] = "processEvent010_18",
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_WAEKBYRT, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ENPC_NUNUBA, QFLAG_TALK);
		for classId, _ in pairs(TALKS_010) do
			quest:SetENpc(classId);
		end
	elseif (sequence == SEQ_010) then
		-- The tower stays open: a lost or abandoned hunt is retried there.
		quest:SetENpc(ENPC_TOWER, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_NUNUBA);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(ENPC_WAEKBYRT, QFLAG_TALK);
	elseif (sequence == SEQ_030) then
		quest:SetENpc(ENPC_NUNUBA, QFLAG_REWARD);
		quest:SetENpc(ENPC_WAEKBYRT);
	end
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_WAEKBYRT) then
		-- The sign-up, with exc20010 inside it.
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventWaekbyrtStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000) then
		if (npcClassId == ENPC_NUNUBA) then
			-- The Trident, and whether you're in.
			local answer = callClientFunction(player, "delegateEvent", player, quest, "processEvent015");
			if (answer == 1) then
				quest:StartSequence(SEQ_010);
			end
		elseif (TALKS_010[npcClassId] ~= nil) then
			callClientFunction(player, "delegateEvent", player, quest, TALKS_010[npcClassId]);
		end
	elseif (seq == SEQ_010) then
		if (npcClassId == ENPC_NUNUBA) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent015_3");
		end
	elseif (seq == SEQ_020) then
		if (npcClassId == ENPC_WAEKBYRT) then
			-- He hears the tower is clear, then his drunk turns up (exc20040).
			callClientFunction(player, "delegateEvent", player, quest, "processEvent040_2");
			callClientFunction(player, "delegateEvent", player, quest, "processEvent040");
			quest:StartSequence(SEQ_030);
		end
	elseif (seq == SEQ_030) then
		if (npcClassId == ENPC_NUNUBA) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent050");
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 2);
			player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
			player:AddGil(REWARD_GIL);
			player:CompleteQuest(quest);
		elseif (npcClassId == ENPC_WAEKBYRT) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent040_2");
		end
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (npcClassId == ENPC_TOWER and seq == SEQ_010) then
		-- exc20020: the lemmings at the tower. It ends on an after-warp
		-- fade, which the warp into the hunt lifts.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		startExc200Hunt(player, quest);
		return;
	end
	player:EndEvent();
end

function startExc200Hunt(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Exc20001", "SimpleContentExc20001", "Quest/QuestDirectorExc20001", 129);
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
	GetWorldManager():DoZoneChangeContent(player, contentArea, HUNT[1], HUNT[2], HUNT[3], HUNT[4], 16);
end

-- QuestDirectorExc20001, once the last lemming is down (a loss never
-- signals the director).
function finishExc200Hunt(player, quest, actor)
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	-- exc20030: the tower cleared.
	callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
	quest:StartSequence(SEQ_020);
	player:EndEvent();
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	GetWorldManager():DoZoneChange(player, 129, nil, 0, 15, TOWER_OUTSIDE[1], TOWER_OUTSIDE[2], TOWER_OUTSIDE[3], TOWER_OUTSIDE[4]);
end

-- SimpleContentExc20001, on a loss: set down outside the tower to try
-- again. The content ends it itself; the director runs in its own Lua state
-- and can't see what happened.
function loseExc200Hunt(player)
	player:SendMessage(0x20, "", "You are defeated.");
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	GetWorldManager():DoZoneChange(player, 129, nil, 0, 15, TOWER_OUTSIDE[1], TOWER_OUTSIDE[2], TOWER_OUTSIDE[3], TOWER_OUTSIDE[4]);
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_000) then
		return MRKR_NUNUBA;
	elseif (seq == SEQ_010) then
		return MRKR_TOWER;
	elseif (seq == SEQ_020) then
		return MRKR_WAEKBYRT;
	elseif (seq == SEQ_030) then
		return MRKR_NUNUBA2;
	end
end
