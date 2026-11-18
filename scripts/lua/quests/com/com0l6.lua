require ("global")
require ("quest")

--[[

Quest Script

Name: 	Ceruleum Shock
Code: 	Com0l6
Id: 	111406
Prereq: Com0l5 complete (a Maelstrom recruit).

Ul'dah has put a ruinous tariff on ceruleum just as the Maelstrom's flagship
needs it. Guincum sends a recruit to Vesper Bay to watch the Hollow Barons,
pirates newly sworn to the Maelstrom, whose riot there is meant to draw off
the Immortal Flames (a duty entered in place, SimpleContentCom0l601) while
their captain raids the ceruleum stores. Lvfrid explains the plan; the raid
itself plays as a cutscene (com0l510), in which Cid Garlond stops the
bloodshed and asks you to meet him at the Limsa Lominsa Landing atop the
Mizzenmast. Zanthael's lift takes you up, and Cid tells you of Dalamud, the
Empire's terminals and the choice ahead.

The client script (com0l6) names the events; seed 132 holds the cast, the
bay trigger and the Flames. The bay is the ferry docks Burning Man (Com0u5)
uses. The Landing has no zone on this server, so Cid and those waiting on
the Landing stand beside Zanthael's lift instead, where the ride sets you
down.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Join the Hollow Barons' riot at Vesper Bay.
SEQ_005	= 5;	-- Speak with Lvfrid.
SEQ_010	= 10;	-- Take Zanthael's lift up to the Landing.
SEQ_015	= 15;	-- Speak with Cid on the Landing.

-- Quest Actors
GUINCUM					= 1500199;
ZANTHAEL				= 1000351;
CID						= 1001572;
LVFRID					= 1000765;	-- an imposing pirate stands in
HOOK_NOSED_PIRATE		= 1000114;	-- "You the scrag they sent to collect the 'lum?"
UNINHIBITED_BUCCANEER	= 1000763;	-- "They did not seem especially immortal"
DISCOMBOBULATED_TRAVELER	= 1000124;	-- "A blighted pirate... steals me bloody purse"
PLUMP_FACED_TRAVELER	= 1000772;	-- "Did you arrive on the ferry?"
AJIN_ZUKAJIN			= 1001700;	-- the Landing: "the chief engineer return unharmed"
MISINFORMED_PIRATE		= 1000079;	-- "Word has begun to spread of the Hollow Barons' raid"
INSCRUTABLE_PIRATE		= 1000116;	-- "You look as if you've seen a ghost"
COQUETTISH_PIRATE		= 1000086;	-- "That's only Cid Garlond"
RAPLULU					= 1001701;	-- "one of the greatest minds in Eorzea"
GZENTSA					= 1001702;	-- "a flock of terns over the bay"
ALDYET					= 1001703;	-- "Those poor terns..."

-- Triggers
VESPER_BAY				= 1090330;

-- Places
VESPER_BAY_DOCKS		= {172, -1620.0, 59.5, 248.0, -1.57};
LANDING					= {133, -440.0, 21.0, 179.0, 0.8};

-- The other companies' sixth missions: Cid's account depends on which of
-- his talks there you have heard, 3 for neither, 1 or 2 for one, 4 for both
-- (1, 2 and 4 all get "you've heard this before").
CID_GRIDANIA			= 111606;
CID_ULDAH				= 111806;

-- Rewards (the client's reward sheet row: an EXP tier in slot 1, seals in slot 5)
REWARD_EXP				= 1541;
REWARD_SEALS			= 300;
COMPANY					= 1;

-- Those at the bay before and after the riot, and those on the Landing:
-- each one's talk.
BAY_CROWD = {
	[HOOK_NOSED_PIRATE]			= "processEvent_005_1",
	[UNINHIBITED_BUCCANEER]		= "processEvent_005_2",
	[DISCOMBOBULATED_TRAVELER]	= "processEvent_005_3",
	[PLUMP_FACED_TRAVELER]		= "processEvent_005_4",
};
LANDING_CROWD = {
	[AJIN_ZUKAJIN]			= "processEvent_015_1",
	[MISINFORMED_PIRATE]	= "processEvent_015_2",
	[INSCRUTABLE_PIRATE]	= "processEvent_015_3",
	[COQUETTISH_PIRATE]		= "processEvent_015_4",
	[RAPLULU]				= "processEvent_015_5",
	[GZENTSA]				= "processEvent_015_6",
	[ALDYET]				= "processEvent_015_7",
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(GUINCUM, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(VESPER_BAY, QFLAG_PUSH, false, true);
		quest:SetENpc(GUINCUM);
		for classId in pairs(BAY_CROWD) do
			quest:SetENpc(classId);
		end
	elseif (sequence == SEQ_005) then
		quest:SetENpc(LVFRID, QFLAG_TALK);
		for classId in pairs(BAY_CROWD) do
			quest:SetENpc(classId);
		end
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ZANTHAEL, QFLAG_TALK);
	elseif (sequence == SEQ_015) then
		quest:SetENpc(CID, QFLAG_REWARD);
		for classId in pairs(LANDING_CROWD) do
			quest:SetENpc(classId);
		end
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (sequence == SEQ_ACCEPT and classId == GUINCUM) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventGUINCUMStart", 0);
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (sequence == SEQ_000 and classId == GUINCUM) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_000");
	elseif ((sequence == SEQ_000 or sequence == SEQ_005) and BAY_CROWD[classId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, BAY_CROWD[classId]);
	elseif (sequence == SEQ_005 and classId == LVFRID) then
		-- the Barons' plan, then the captain's raid and Cid (com0l510)
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_005");
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010");
		quest:StartSequence(SEQ_010);
	elseif (sequence == SEQ_010 and classId == ZANTHAEL) then
		-- the lift up the Mizzenmast; the cutscene ends on a warp
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_elevator_nq2");
		quest:StartSequence(SEQ_015);
		player:EndEvent();
		GetWorldManager():DoZoneChange(player, LANDING[1], nil, 0, 15,
			LANDING[2], LANDING[3], LANDING[4], LANDING[5]);
		return;
	elseif (sequence == SEQ_015 and LANDING_CROWD[classId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, LANDING_CROWD[classId]);
	elseif (sequence == SEQ_015 and classId == CID) then
		-- Dalamud, the Empire's terminals, and the wind at the helm
		local heardGridania = player:IsQuestCompleted(CID_GRIDANIA);
		local heardUldah = player:IsQuestCompleted(CID_ULDAH);
		local heard = 3;
		if (heardGridania and heardUldah) then
			heard = 4;
		elseif (heardGridania) then
			heard = 1;
		elseif (heardUldah) then
			heard = 2;
		end
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_015", heard);
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 5);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddSeals(COMPANY, REWARD_SEALS);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onPush(player, quest, npc)
	if (npc:GetActorClassId() == VESPER_BAY and quest:getSequence() == SEQ_000) then
		startCom0l6Content(player, quest);
		return;
	end
	player:EndEvent();
end

-- The riot, a duty entered in place (spawnType 0x16). Its director
-- (QuestDirectorCom0l601) sends you on to Lvfrid once the Flames fall back.
function startCom0l6Content(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Com0l601", "SimpleContentCom0l601", "Quest/SimpleQuestBattle/QuestDirectorCom0l601");
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
	GetWorldManager():DoZoneChangeContent(player, contentArea,
		player.positionX, player.positionY, player.positionZ, player.rotation, 0x16);
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
