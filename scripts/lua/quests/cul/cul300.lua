require ("global")
require ("quest")

--[[

Quest Script

Name:	Mystery of the Gastronome Gone Home
Code:	Cul300
Id:	110441
Prereq: Level 30, Culinarian

Charlys says Prudentia is low again (processEventCharlysStart, 1 =
accepted). She tells you a favorite customer, a merchant from Ul'dah, has
stopped coming (cul30010). Charlys places him at Sunsilk Tapestries
(processEvent012); the receptionist Deaustie points him out
(processEvent014). The merchant won't say why (processEvent016), brushes
off your first try, then gives in to your persistence (processEvent016_2,
016_1) and owns that he left because the Qiqirn love Prudentia's stew
(cul30020). Charlys takes it to the guildmaster and sends you to the alley
behind the restaurant (processEvent025), where Prudentia is feeding a party
of Qiqirn (cul30030). Back with Charlys (processEvent035) you are paid
30,000 gil and 3,000 experience, like the other level-30 guild quests.

The merchant has no actor in 1.23b, so he is a push circle by Deaustie's
counter; the alley is the same circle as Cul200's.

Journal: steps 49-57 of the Limsa Lominsa quest journal sheet.

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Find Prudentia.
SEQ_010	= 10;  -- Report to Charlys.
SEQ_012	= 12;  -- Sunsilk Tapestries in Ul'dah.
SEQ_014	= 14;  -- Speak with the merchant.
SEQ_016	= 16;  -- Persuade him.
SEQ_018	= 18;  -- Speak with him again.
SEQ_020	= 20;  -- Report to Charlys.
SEQ_025	= 25;  -- The alley behind the Bismarck.
SEQ_030	= 30;  -- Report to Charlys.

-- Quest flags
FLAG_TRIED	= 0; -- the merchant has brushed you off once

-- Actor Class Ids
ENPC_GERULF		= 1000063;
ENPC_AENTFOET	= 1000064;
ENPC_FRAILOISE	= 1000065;
ENPC_CHARLYS	= 1000138;
ENPC_PRUDENTIA	= 1000168;
ENPC_PULMIA		= 1000169;
ENPC_RSUSHMO	= 1000170;
ENPC_KIKICHUA	= 1000171;
ENPC_HOBRIAUT	= 1000172;
ENPC_HLAHONO	= 1000250;
ENPC_DEAUSTIE	= 1000293;
ENPC_ALLEY		= 1091124; -- push circle in the alley behind the Bismarck
ENPC_MERCHANT	= 1091125; -- push circle by Deaustie's counter

-- Quest Markers (each names its scene in the client's marker index)
MRKR_PRUDENTIA	= 11044101;
MRKR_MERCHANT	= 11044102;
MRKR_ALLEY		= 11044103;

REWARD_GIL	= 30000;
REWARD_EXP	= 3000;

-- Scenes that end on an after-warp fade set you down here (Limsa Lominsa
-- upper decks; town cut frames are offset from server coordinates, so these
-- are estimates).
LIMSA_ZONE = 230;
CHARLYS_DESK = { -512.2, 42.3, 30.7, 2.77 };
ALLEY = { -493.0, 39.5, 30.0, 0.8 };

-- What the cooks say between steps. The client script names no speaker;
-- these follow the lines' content.
TALKS = {
	[SEQ_000] = {
		[ENPC_PULMIA] = "processEvent005_2",
		[ENPC_CHARLYS] = "processEvent005_3",
		[ENPC_GERULF] = "processEvent005_4",
		[ENPC_FRAILOISE] = "processEvent005_5",
		[ENPC_KIKICHUA] = "processEvent005_6",
		[ENPC_HOBRIAUT] = "processEvent005_7",
		[ENPC_RSUSHMO] = "processEvent005_8",
		[ENPC_HLAHONO] = "processEvent005_9",
	},
	[SEQ_010] = {
		[ENPC_PRUDENTIA] = "processEvent010_2",
	},
	[SEQ_012] = {
		[ENPC_CHARLYS] = "processEvent012_2",
	},
	[SEQ_014] = {
		[ENPC_DEAUSTIE] = "processEvent014_2",
	},
	[SEQ_016] = {
		[ENPC_DEAUSTIE] = "processEvent014_2",
	},
	[SEQ_018] = {
		[ENPC_DEAUSTIE] = "processEvent014_2",
	},
	[SEQ_025] = {
		[ENPC_CHARLYS] = "processEvent025_2",
		[ENPC_PULMIA] = "processEvent025_3",
		[ENPC_GERULF] = "processEvent025_4",
		[ENPC_AENTFOET] = "processEvent025_5",
		[ENPC_FRAILOISE] = "processEvent025_6",
		[ENPC_HOBRIAUT] = "processEvent025_7",
		[ENPC_KIKICHUA] = "processEvent025_8",
		[ENPC_RSUSHMO] = "processEvent025_9",
	},
	[SEQ_030] = {
		[ENPC_PRUDENTIA] = "processEvent030_2",
		[ENPC_PULMIA] = "processEvent030_3",
		[ENPC_RSUSHMO] = "processEvent030_4",
		[ENPC_GERULF] = "processEvent030_5",
		[ENPC_FRAILOISE] = "processEvent030_6",
		[ENPC_HOBRIAUT] = "processEvent030_7",
		[ENPC_KIKICHUA] = "processEvent030_8",
		[ENPC_AENTFOET] = "processEvent030_9",
	},
};

-- Who moves the quest on in each sequence (by talking).
TARGETS = {
	[SEQ_000] = ENPC_PRUDENTIA,
	[SEQ_010] = ENPC_CHARLYS,
	[SEQ_012] = ENPC_DEAUSTIE,
	[SEQ_020] = ENPC_CHARLYS,
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_CHARLYS, QFLAG_TALK);
		return;
	end
	if (TALKS[sequence] ~= nil) then
		for classId, _ in pairs(TALKS[sequence]) do
			quest:SetENpc(classId);
		end
	end
	if (TARGETS[sequence] ~= nil) then
		quest:SetENpc(TARGETS[sequence], QFLAG_TALK);
	elseif (sequence == SEQ_014 or sequence == SEQ_016 or sequence == SEQ_018) then
		quest:SetENpc(ENPC_MERCHANT, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_025) then
		quest:SetENpc(ENPC_ALLEY, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_030) then
		quest:SetENpc(ENPC_CHARLYS, QFLAG_REWARD);
	end
end

local function warpTo(player, zoneId, spot)
	GetWorldManager():DoZoneChange(player, zoneId, nil, 0, 15, spot[1], spot[2], spot[3], spot[4]);
end

local function delegate(player, quest, fn)
	return callClientFunction(player, "delegateEvent", player, quest, fn);
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_CHARLYS) then
		local accepted = delegate(player, quest, "processEventCharlysStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and npcClassId == ENPC_PRUDENTIA) then
		-- cul30010: the customer who stopped coming.
		delegate(player, quest, "processEvent010");
		quest:StartSequence(SEQ_010);
	elseif (seq == SEQ_010 and npcClassId == ENPC_CHARLYS) then
		-- The merchant from Sunsilk Tapestries.
		delegate(player, quest, "processEvent012");
		quest:StartSequence(SEQ_012);
	elseif (seq == SEQ_012 and npcClassId == ENPC_DEAUSTIE) then
		-- Deaustie points him out. (014_1 is her greeting for someone she
		-- already expects; the quest uses the stranger's one.)
		delegate(player, quest, "processEvent014");
		quest:StartSequence(SEQ_014);
	elseif (seq == SEQ_020 and npcClassId == ENPC_CHARLYS) then
		-- The guildmaster must decide; the Qiqirn in the alley. It ends on
		-- an after-warp fade.
		delegate(player, quest, "processEvent025");
		quest:StartSequence(SEQ_025);
		player:EndEvent();
		warpTo(player, LIMSA_ZONE, CHARLYS_DESK);
		return;
	elseif (seq == SEQ_030 and npcClassId == ENPC_CHARLYS) then
		-- Prudentia's spirits lifted, and payment.
		delegate(player, quest, "processEvent035");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 2);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddGil(REWARD_GIL);
		player:CompleteQuest(quest);
	elseif (TALKS[seq] ~= nil and TALKS[seq][npcClassId] ~= nil) then
		delegate(player, quest, TALKS[seq][npcClassId]);
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (npcClassId == ENPC_MERCHANT and seq == SEQ_014) then
		-- He won't tell.
		delegate(player, quest, "processEvent016");
		quest:StartSequence(SEQ_016);
	elseif (npcClassId == ENPC_MERCHANT and seq == SEQ_016) then
		local data = quest:GetData();
		if (not data:GetFlag(FLAG_TRIED)) then
			-- The first try falls flat.
			delegate(player, quest, "processEvent016_2");
			data:SetFlag(FLAG_TRIED);
		else
			-- Persistence wins him over.
			delegate(player, quest, "processEvent016_1");
			quest:StartSequence(SEQ_018);
		end
	elseif (npcClassId == ENPC_MERCHANT and seq == SEQ_018) then
		-- cul30020: the Qiqirn and the stew.
		delegate(player, quest, "processEvent020");
		quest:StartSequence(SEQ_020);
	elseif (npcClassId == ENPC_ALLEY and seq == SEQ_025) then
		-- cul30030: Prudentia and the Qiqirn. It ends on an after-warp fade.
		delegate(player, quest, "processEvent030");
		quest:StartSequence(SEQ_030);
		player:EndEvent();
		warpTo(player, LIMSA_ZONE, ALLEY);
		return;
	end
	quest:UpdateENPCs();
	player:EndEvent();
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_000) then
		return MRKR_PRUDENTIA;
	elseif (seq == SEQ_014 or seq == SEQ_016 or seq == SEQ_018) then
		return MRKR_MERCHANT;
	elseif (seq == SEQ_025) then
		return MRKR_ALLEY;
	end
end
