require ("global")
require ("quest")
require ("modifiers")

--[[

Quest Script

Name:	Here There Be Pirates
Code:	Pgl300
Id:	110061
Prereq: Level 30, Pugilist, Pgl200

Titinin sends you after the pirates behind the Mirage's counterfeit chips
(pgl30010). On the Astalicia, Waekbyrt's talk is cut short by the Kraken's
Arms (pgl30020); Titinin answers by linkpearl and sends you to the
Mizzenmast, where U'mallibo and Hurrey point you to the Misery (pgl30030).
In the ship's hold (content Pgl30001) you search a chest and a door until
the deckhands notice you; beat them, and Hurrey sends you back to Ul'dah
(pgl30040). Titinin takes the mold (pgl30050) and asks you to wait; the
Echo shows three pugilists' part in the plot (pgl30060-80), and Gagaruna
pays 30,000 gil and 3,000 experience (processEvent090).

The Misery has no map of its own: the hold is the one under the deck of
the Rhotano Sea ship in zone 192 (man2l0's EVENTDOOR_SHIP1 drop), so the
content runs there. U'mallibo and Hurrey ship stripped, so the Mizzenmast
meeting and the Misery's gangway are push circles (seed 295).

]]

-- Sequence Numbers
SEQ_010	= 10;  -- Find the pirates aboard the Astalicia (Waekbyrt).
SEQ_020	= 20;  -- Titinin's linkpearl call.
SEQ_025	= 25;  -- Go to the Mizzenmast.
SEQ_030	= 30;  -- Steal onto the Misery, by the Sailors Ward door.
SEQ_035	= 35;  -- Search the hold (content Pgl30001).
SEQ_040	= 40;  -- Report to Titinin.
SEQ_050	= 50;  -- Use the Echo on the pugilists.
SEQ_060	= 60;  -- Speak with Gagaruna for the reward.

-- Actor Class Ids
ENPC_GAGARUNA		= 1000862;
ENPC_TITININ		= 1000934;
ENPC_WAEKBYRT		= 1000003;
ENPC_MELISIE		= 1001009;
ENPC_GUNNULF		= 1001256;
ENPC_SHAMANI		= 1001012;
ENPC_HALSTEIN		= 1001007;
ENPC_HEIBERT		= 1001257;
ENPC_IPAGHLO		= 1001260;
ENPC_KUKUMUKO		= 1000070;
ENPC_MIZZENMAST		= 1090515; -- seed 295: push circle at the inn counter
ENPC_MISERY			= 1090516; -- seed 295: push circle by the Sailors Ward door
ENPC_HOLD_CHEST		= 1080017; -- sparkles spawned in the hold by SimpleContentPgl30001
ENPC_HOLD_DOOR		= 1080018;

-- Quest Markers (each names its scene in the client's marker index; 090
-- has none, so Gagaruna's start marker serves)
MRKR_GAGARUNA		= 11006101;
MRKR_ASTALICIA		= 11006102;
MRKR_MIZZENMAST		= 11006103;
MRKR_MISERY			= 11006104;
MRKR_TITININ		= 11006105;
MRKR_KUKUMUKO		= 11006106;
MRKR_HALSTEIN		= 11006107;
MRKR_SHAMANI		= 11006108;

-- Quest Flags
FLAG_SEARCHED_CHEST	= 0;
FLAG_SEARCHED_DOOR	= 1;
FLAG_ECHO_KUKUMUKO	= 2;
FLAG_ECHO_HALSTEIN	= 3;
FLAG_ECHO_SHAMANI	= 4;

-- Titinin's linkpearl reply (says 24-26) after the Astalicia, on the
-- Platinum Mirage pearl (id 10 in the client's NPC linkpearl sheet).
NPCLS_MIRAGE = 10;
NPCLS_MSGS = { 24, 25, 26 };
TITININ_DISPLAY_ID = 1400021;

-- The hold's search lines (the client's says 113/114 don't render through
-- SendGameMessage here, as in pgl200.lua).
TEXT_CHEST_EMPTY	= "You search the chest. It is empty.";
TEXT_DOOR_LOCKED	= "You try the door. It will not open.";

REWARD_GIL	= 30000;
REWARD_EXP	= 3000;

-- Spots: zone, x, y, z, rotation. Heights walked unless noted.
HOLD_ENTRY = { 192, 1823.58, -61.65, 1816.1, 2.42 };	-- man2l0's hold drop
SAILORS_TERRACE = { 230, -422.8, 42.0, 418.5, 0.0 };	-- pgl30040's terrace by the Market Wards door
MIRAGE_TITININ = { 175, -172.6, 190.0, 117.2, 1.57 };	-- facing Titinin

-- Chatter while the step is open: { [sequence] = { [class] = event } }.
TALKS = {
	[SEQ_010] = {
		[ENPC_TITININ] = "processEvent010_2",
		[ENPC_IPAGHLO] = "processEvent010_3",
		[ENPC_HALSTEIN] = "processEvent010_4",
		[ENPC_MELISIE] = "processEvent010_5",
		[ENPC_HEIBERT] = "processEvent010_6",
		[ENPC_GUNNULF] = "processEvent010_7",
		[ENPC_SHAMANI] = "processEvent010_8",
		[ENPC_GAGARUNA] = "processEvent010_9",
	},
	[SEQ_050] = {
		[ENPC_GAGARUNA] = "processEvent050_2",
		[ENPC_IPAGHLO] = "processEvent050_3",
		[ENPC_MELISIE] = "processEvent050_4",
		[ENPC_HEIBERT] = "processEvent050_5",
		[ENPC_GUNNULF] = "processEvent050_6",
		[ENPC_TITININ] = "processEvent050_10",
	},
	[SEQ_060] = {
		[ENPC_TITININ] = "processEvent080_2",
	},
};

-- The Echoes run in order; a subject whose turn hasn't come says only
-- his plain line (the client's _2 handlers).
ECHOES = {
	{ class = ENPC_KUKUMUKO, flag = FLAG_ECHO_KUKUMUKO, event = "processEvent060" },
	{ class = ENPC_HALSTEIN, flag = FLAG_ECHO_HALSTEIN, event = "processEvent070", early = "processEvent060_2" },
	{ class = ENPC_SHAMANI, flag = FLAG_ECHO_SHAMANI, event = "processEvent080", early = "processEvent070_2" },
};

MIRAGE_FOLK = { ENPC_TITININ, ENPC_GAGARUNA, ENPC_MELISIE, ENPC_GUNNULF, ENPC_SHAMANI, ENPC_HALSTEIN, ENPC_HEIBERT, ENPC_IPAGHLO };

function onStart(player, quest)
	quest:StartSequence(SEQ_010);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_GAGARUNA, QFLAG_TALK);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_WAEKBYRT, QFLAG_TALK);
		for _, classId in ipairs(MIRAGE_FOLK) do
			quest:SetENpc(classId);
		end
	elseif (sequence == SEQ_025) then
		quest:SetENpc(ENPC_MIZZENMAST, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_030) then
		-- Stays open: a lost or abandoned fight is retried from here.
		quest:SetENpc(ENPC_MISERY, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_035) then
		local data = quest:GetData();
		quest:SetENpc(ENPC_MISERY, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_HOLD_CHEST, data:GetFlag(FLAG_SEARCHED_CHEST) and QFLAG_NONE or QFLAG_TALK);
		quest:SetENpc(ENPC_HOLD_DOOR, data:GetFlag(FLAG_SEARCHED_DOOR) and QFLAG_NONE or QFLAG_TALK);
	elseif (sequence == SEQ_040) then
		quest:SetENpc(ENPC_TITININ, QFLAG_TALK);
		quest:SetENpc(ENPC_GAGARUNA);
	elseif (sequence == SEQ_050) then
		local data = quest:GetData();
		local nextEcho = nextEchoIndex(data);
		for i, echo in ipairs(ECHOES) do
			quest:SetENpc(echo.class, (i == nextEcho) and QFLAG_TALK or QFLAG_NONE);
		end
		for _, classId in ipairs({ ENPC_TITININ, ENPC_GAGARUNA, ENPC_MELISIE, ENPC_GUNNULF, ENPC_HEIBERT, ENPC_IPAGHLO }) do
			quest:SetENpc(classId);
		end
	elseif (sequence == SEQ_060) then
		quest:SetENpc(ENPC_GAGARUNA, QFLAG_REWARD);
		quest:SetENpc(ENPC_TITININ);
	end
end

local function warpTo(player, spot)
	GetWorldManager():DoZoneChange(player, spot[1], nil, 0, 15, spot[2], spot[3], spot[4], spot[5]);
end

function nextEchoIndex(data)
	for i, echo in ipairs(ECHOES) do
		if (not data:GetFlag(echo.flag)) then
			return i;
		end
	end
	return nil;
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();
	local data = quest:GetData();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_GAGARUNA) then
		-- pgl30010: Titinin's charge (1 = accepted).
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventGagarunaStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_010 and npcClassId == ENPC_WAEKBYRT) then
		-- pgl30020: the Kraken's Arms and Captain Carvallain. Titinin
		-- calls by linkpearl after.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		player:AddNpcLs(NPCLS_MIRAGE);
		quest:NewNpcLsMsg(NPCLS_MIRAGE);
		quest:StartSequence(SEQ_020);
	elseif (seq == SEQ_035 and (npcClassId == ENPC_HOLD_CHEST or npcClassId == ENPC_HOLD_DOOR)) then
		searchHold(player, quest, npc, npcClassId);
		player:EndEvent();
		return;
	elseif (seq == SEQ_040 and npcClassId == ENPC_TITININ) then
		-- pgl30050: the mold handed over. It ends on an after-warp fade.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050");
		quest:StartSequence(SEQ_050);
		player:EndEvent();
		warpTo(player, MIRAGE_TITININ);
		return;
	elseif (seq == SEQ_050 and echoFor(npcClassId) ~= nil) then
		local i, echo = echoFor(npcClassId);
		local nextEcho = nextEchoIndex(data);
		if (data:GetFlag(echo.flag)) then
			-- Seen: the step's plain chatter (050_7-9).
			local seen = { [ENPC_KUKUMUKO] = "processEvent050_9", [ENPC_HALSTEIN] = "processEvent050_7", [ENPC_SHAMANI] = "processEvent050_8" };
			callClientFunction(player, "delegateEvent", player, quest, seen[npcClassId]);
		elseif (i ~= nextEcho) then
			if (echo.early ~= nil) then
				callClientFunction(player, "delegateEvent", player, quest, echo.early);
			end
		else
			-- The pre-Echo line and the Echo prompt: 1 plays the scene.
			local seen = callClientFunction(player, "delegateEvent", player, quest, echo.event);
			if (seen == 1) then
				data:SetFlag(echo.flag);
				if (nextEchoIndex(data) == nil) then
					quest:StartSequence(SEQ_060);
				else
					-- Re-run the step so the next subject lights up.
					quest:StartSequence(SEQ_050);
				end
			end
		end
	elseif (seq == SEQ_060 and npcClassId == ENPC_GAGARUNA) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent090");
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

function echoFor(classId)
	for i, echo in ipairs(ECHOES) do
		if (echo.class == classId) then
			return i, echo;
		end
	end
	return nil;
end

-- The hold's chest is empty and its door locked; once both are tried, the
-- deckhands notice (SimpleContentPgl30001 watches the two flags).
function searchHold(player, quest, npc, npcClassId)
	local data = quest:GetData();
	if (npcClassId == ENPC_HOLD_CHEST) then
		player:SendMessage(0x20, "", TEXT_CHEST_EMPTY);
		data:SetFlag(FLAG_SEARCHED_CHEST);
	else
		player:SendMessage(0x20, "", TEXT_DOOR_LOCKED);
		data:SetFlag(FLAG_SEARCHED_DOOR);
	end
	player:HideActor(npc.Id);
	quest:UpdateENPCs();
end

function onPush(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_025 and npcClassId == ENPC_MIZZENMAST) then
		-- pgl30030: U'mallibo and Hurrey at the inn.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
		quest:StartSequence(SEQ_030);
	elseif ((seq == SEQ_030 or seq == SEQ_035) and npcClassId == ENPC_MISERY) then
		startPgl300Hold(player, quest);
		return;
	end
	quest:UpdateENPCs();
	player:EndEvent();
end

function onNpcLS(player, quest, from, msgStep)
	local seq = quest:GetSequence();

	if (from == NPCLS_MIRAGE and (seq == SEQ_020 or seq == SEQ_025)) then
		player:SendGameMessageLocalizedDisplayName(quest, NPCLS_MSGS[msgStep], MESSAGE_TYPE_NPC_LINKSHELL, TITININ_DISPLAY_ID);
		if (msgStep >= #NPCLS_MSGS) then
			quest:EndOfNpcLsMsgs();
		else
			quest:ReadNpcLsMsg();
		end
		if (seq == SEQ_020) then
			quest:StartSequenceForNpcLs(SEQ_025);
		end
	end

	player:EndEvent();
end

function startPgl300Hold(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Pgl30001", "SimpleContentPgl30001", "Quest/QuestDirectorPgl30001", HOLD_ENTRY[1]);
	if (contentArea == nil) then
		player:EndEvent();
		return;
	end
	quest:StartSequence(SEQ_035);
	local director = contentArea:GetContentDirector();
	player:AddDirector(director);
	director:StartDirector(false);
	player:KickEvent(director, "noticeEvent", true);
	player:SetLoginDirector(director);
	player:EndEvent();
	GetWorldManager():DoZoneChangeContent(player, contentArea, HOLD_ENTRY[2], HOLD_ENTRY[3], HOLD_ENTRY[4], HOLD_ENTRY[5], 16);
end

-- QuestDirectorPgl30001, once the deckhands are down (a loss never
-- signals the director).
function finishPgl300Hold(player, quest, actor)
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	-- pgl30040: off the ship, Hurrey sends you on. It ends on an
	-- after-warp fade.
	callClientFunction(player, "delegateEvent", player, quest, "processEvent040");
	quest:StartSequence(SEQ_040);
	player:EndEvent();
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	warpTo(player, SAILORS_TERRACE);
end

-- SimpleContentPgl30001, on a loss (pinned at 1 HP, or out of time): set
-- down by the gangway to try again. The searches stay done, so the next
-- try goes straight to the fight.
function losePgl300Hold(player, timedOut)
	if (timedOut) then
		player:SendMessage(0x20, "", "Time has run out.");
	else
		player:SendMessage(0x20, "", "You are defeated.");
	end
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	warpTo(player, SAILORS_TERRACE);
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_010) then
		return MRKR_ASTALICIA;
	elseif (seq == SEQ_020 or seq == SEQ_025) then
		return MRKR_MIZZENMAST;
	elseif (seq == SEQ_030 or seq == SEQ_035) then
		return MRKR_MISERY;
	elseif (seq == SEQ_040) then
		return MRKR_TITININ;
	elseif (seq == SEQ_050) then
		local i = nextEchoIndex(quest:GetData());
		return ({ MRKR_KUKUMUKO, MRKR_HALSTEIN, MRKR_SHAMANI })[i or 1];
	elseif (seq == SEQ_060) then
		return MRKR_GAGARUNA;
	end
end
