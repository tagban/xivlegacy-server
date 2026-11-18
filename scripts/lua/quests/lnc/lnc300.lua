require ("global")
require ("quest")
require ("modifiers")

--[[

Quest Script

Name:	Culture Shock
Code:	Lnc300
Id:	110181
Prereq: Level 30, Lancer

J'moldva sends you to Ul'dah to find an ally against the Empire among the
Ala Mhigan pugilists of the Platinum Mirage (lnc30010). Gagaruna has the
Mirage's answer: see to the Black Shroud before asking anything of Ul'dah
(lnc30020). A pugilist, Dreues, demands a hundred thousand gil just to hear
you, then a fistfight, and ends up your man in Ul'dah (lnc30030). Back in
the Wailing Barracks, word comes of an Ul'dahn caravan stranded south of
the wood (lnc30040). You find it (lnc30050) as the beasts fall on it
(content Lnc30001); a moogle lies trampled in the chaos (lnc30060), and the
Ul'dahns go on their way (lnc30065). J'moldva hears your report (lnc30070)
and Willelda pays you 30,000 gil and 3,000 experience.

This is the 1.23b version of the quest (English dialogue 03/A2/04/02); the
2010 version on ZAM (Dreues' tax, five pterocs at Lifemend Stump) was
rewritten.

]]

-- Sequence Numbers
SEQ_005	= 5;   -- Seek an ally at the Platinum Mirage in Ul'dah.
SEQ_010	= 10;  -- Find a pugilist willing to hear you out.
SEQ_020	= 20;  -- Report to J'moldva.
SEQ_030	= 30;  -- Find the merchant caravan south of the wood.
SEQ_040	= 40;  -- Report to J'moldva.
SEQ_050	= 50;  -- Collect your pay from Willelda.

-- Actor Class Ids
ENPC_WILLELDA		= 1000242;
ENPC_JMOLDVA		= 1000599;
ENPC_GAGARUNA		= 1000862;
ENPC_DREUES			= 1000402; -- seed 293: the Ala Mhigan pugilist, given a spawn
ENPC_CARAVAN_ROAD	= 1090509; -- seed 293: push circle at the caravan

-- Quest Markers
MRKR_JMOLDVA	= 11018101;
MRKR_GAGARUNA	= 11018102;
MRKR_DREUES		= 11018103;
MRKR_CARAVAN	= 11018104;
MRKR_WILLELDA	= 11018105;

REWARD_GIL	= 30000;
REWARD_EXP	= 3000;

-- Inside the Platinum Mirage, before Gagaruna (man1u0's lobby spot);
-- lnc30020 ends on an after-warp fade.
MIRAGE_LOBBY = { -182.6, 190.1, 112.2, 0.0 };
-- The caravan on the Central Shroud road (the lnc30050/60/65 tracks,
-- heights from the client's ground mesh): where the beasts are fought,
-- and where you are set down afterwards.
CARAVAN_FIGHT = { 400.0, 4.65, 25.0, 0.0 };
CARAVAN_GROUND = { 393.0, 5.55, 22.0, 0.0 };

-- What the Wailers say between steps (the client script names no speaker;
-- these follow the lines' content).
TALKS_WILLELDA = {
	[SEQ_005] = "processEvent010_2",
};
TALKS_JMOLDVA = {
	[SEQ_005] = "processEvent010_3",
	[SEQ_030] = "processEvent040_2",
	[SEQ_050] = "processEvent070_2",
};

function onStart(player, quest)
	quest:StartSequence(SEQ_005);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_JMOLDVA, QFLAG_TALK);
	elseif (sequence == SEQ_005) then
		quest:SetENpc(ENPC_GAGARUNA, QFLAG_TALK);
		quest:SetENpc(ENPC_JMOLDVA);
		quest:SetENpc(ENPC_WILLELDA);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_DREUES, QFLAG_TALK);
		quest:SetENpc(ENPC_GAGARUNA);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(ENPC_JMOLDVA, QFLAG_TALK);
		quest:SetENpc(ENPC_DREUES);
	elseif (sequence == SEQ_030) then
		-- Stays open: a lost or abandoned fight is retried from here.
		quest:SetENpc(ENPC_CARAVAN_ROAD, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_JMOLDVA);
	elseif (sequence == SEQ_040) then
		quest:SetENpc(ENPC_JMOLDVA, QFLAG_TALK);
	elseif (sequence == SEQ_050) then
		quest:SetENpc(ENPC_WILLELDA, QFLAG_REWARD);
		quest:SetENpc(ENPC_JMOLDVA);
	end
end

local function warpTo(player, zoneId, spot)
	GetWorldManager():DoZoneChange(player, zoneId, nil, 0, 15, spot[1], spot[2], spot[3], spot[4]);
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_JMOLDVA) then
		-- lnc30010: the search for an ally (1 = "I will do what I can").
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventJMoldvaStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (npcClassId == ENPC_GAGARUNA and seq == SEQ_005) then
		-- lnc30020: the Mirage's terms. It ends on an after-warp fade.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		quest:StartSequence(SEQ_010);
		player:EndEvent();
		warpTo(player, 175, MIRAGE_LOBBY);
		return;
	elseif (npcClassId == ENPC_DREUES and seq == SEQ_010) then
		-- lnc30030: the pugilist's tax and the fistfight. Paying or not,
		-- he comes round.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
		quest:StartSequence(SEQ_020);
	elseif (npcClassId == ENPC_JMOLDVA and seq == SEQ_020) then
		-- lnc30040: the report, and the caravan's call for an escort.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent040");
		quest:StartSequence(SEQ_030);
	elseif (npcClassId == ENPC_JMOLDVA and seq == SEQ_040) then
		-- lnc30070: J'moldva hears how it went.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent070");
		quest:StartSequence(SEQ_050);
	elseif (npcClassId == ENPC_WILLELDA and seq == SEQ_050) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent075");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 2);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddGil(REWARD_GIL);
		player:CompleteQuest(quest);
	elseif (npcClassId == ENPC_WILLELDA and TALKS_WILLELDA[seq] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, TALKS_WILLELDA[seq]);
	elseif (npcClassId == ENPC_JMOLDVA and TALKS_JMOLDVA[seq] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, TALKS_JMOLDVA[seq]);
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_030 and npcClassId == ENPC_CARAVAN_ROAD) then
		-- lnc30050: the caravan, and something in the trees. It ends on
		-- an after-warp fade, which the move into the fight lifts.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050");
		startLnc300Fight(player, quest);
		return;
	end
	quest:UpdateENPCs();
	player:EndEvent();
end

function startLnc300Fight(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Lnc30001", "SimpleContentLnc30001", "Quest/QuestDirectorLnc30001", 150);
	if (contentArea == nil) then
		player:EndEvent();
		warpTo(player, 150, CARAVAN_GROUND);
		return;
	end
	local director = contentArea:GetContentDirector();
	player:AddDirector(director);
	director:StartDirector(false);
	player:KickEvent(director, "noticeEvent", true);
	player:SetLoginDirector(director);
	player:EndEvent();
	GetWorldManager():DoZoneChangeContent(player, contentArea, CARAVAN_FIGHT[1], CARAVAN_FIGHT[2], CARAVAN_FIGHT[3], CARAVAN_FIGHT[4], 16);
end

-- QuestDirectorLnc30001, once the beasts are down (a loss never signals
-- the director).
function finishLnc300Fight(player, quest, actor)
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	-- lnc30060: the trampled moogle; lnc30065: the caravan moves on, on an
	-- after-warp fade.
	callClientFunction(player, "delegateEvent", player, quest, "processEvent060");
	callClientFunction(player, "delegateEvent", player, quest, "processEvent065");
	quest:StartSequence(SEQ_040);
	player:EndEvent();
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	warpTo(player, 150, CARAVAN_GROUND);
end

-- SimpleContentLnc30001, on a loss: set down by the road to try again. The
-- director runs in its own Lua state and can't see it.
function loseLnc300Fight(player)
	player:SendMessage(0x20, "", "You are defeated.");
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	warpTo(player, 150, CARAVAN_GROUND);
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_020 or seq == SEQ_040) then
		return MRKR_JMOLDVA;
	elseif (seq == SEQ_005) then
		return MRKR_GAGARUNA;
	elseif (seq == SEQ_010) then
		return MRKR_DREUES;
	elseif (seq == SEQ_030) then
		return MRKR_CARAVAN;
	elseif (seq == SEQ_050) then
		return MRKR_WILLELDA;
	end
end
