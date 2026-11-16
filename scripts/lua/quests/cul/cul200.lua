require ("global")
require ("quest")

--[[

Quest Script

Name:	Showdown
Code:	Cul200
Id:	110440
Prereq: Level 20, Culinarian

Charlys welcomes you to the Bismarck and sends you to its two star chefs
(processEventCharlysStart: join the guild, then accept; 1 = accepted).
Prudentia and Pulmia introduce themselves and race to fill an order for
thirty (cul20010). You pick a side (processEvent015 for Prudentia,
processEvent017 for Pulmia; 1 = yes) and cook the dish she asks for; the
contest is decided (cul20020), the next order goes to Pulmia, and
Prudentia slips out the back. In the alley she asks what is wrong with her
cooking and thanks you (cul20030): 20,000 gil and 2,000 experience, like
the other level-20 guild quests (the client's reward table has no row for
it).

The dish is a crafted good: the chef checks the bag for it and has a
hurry-up line for when it isn't there yet. The journal names only
Prudentia's piping hot pie crust, so Pulmia takes the same dish.

Journal: steps 39-42 of the Limsa Lominsa quest journal sheet.

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Speak with Prudentia and Pulmia.
SEQ_010	= 10;  -- Choose a chef to help.
SEQ_015	= 15;  -- Cook the dish she asked for.
SEQ_020	= 20;  -- Find Prudentia behind the restaurant.

-- Quest flags
FLAG_PULMIA	= 0; -- set when you chose to help Pulmia

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
ENPC_TITTERING	= 1000253; -- the Bismarck's diners
ENPC_SUSPICIOUS	= 1000254;
ENPC_ENRAPTURED	= 1000255;
ENPC_BEGGAR		= 1000256;
ENPC_SHOPKEEP	= 1000257;
ENPC_ALLEY		= 1091124; -- push circle in the alley behind the Bismarck

-- Items
ITEM_PIE_CRUST	= 11000069; -- Piping Hot Pie Crust

-- Quest Markers (each names its scene in the client's marker index)
MRKR_CHEFS		= 11044001;
MRKR_PRUDENTIA	= 11044002;
MRKR_PULMIA		= 11044003;
MRKR_ALLEY		= 11044004;

REWARD_GIL	= 20000;
REWARD_EXP	= 2000;

-- Scenes that end on an after-warp fade set you down here (Limsa Lominsa
-- upper decks; town cut frames are offset from server coordinates, so these
-- are estimates).
LIMSA_ZONE = 230;
KITCHEN = { -508.4, 42.3, 37.6, 0.48 }; -- in front of Prudentia's station
ALLEY = { -493.0, 39.5, 30.0, 0.8 };

-- What the cooks and diners say between steps. The client script names no
-- speaker; these follow the lines' content.
TALKS = {
	[SEQ_000] = {
		[ENPC_GERULF] = "processEvent005_2",
		[ENPC_AENTFOET] = "processEvent005_3",
		[ENPC_KIKICHUA] = "processEvent005_4",
		[ENPC_HOBRIAUT] = "processEvent005_5",
		[ENPC_FRAILOISE] = "processEvent005_6",
		[ENPC_CHARLYS] = "processEvent005_7",
	},
	[SEQ_015] = {
		[ENPC_CHARLYS] = "processEvent010_2",
	},
	[SEQ_020] = {
		[ENPC_TITTERING] = "processEvent020_2",
		[ENPC_SUSPICIOUS] = "processEvent020_3",
		[ENPC_ENRAPTURED] = "processEvent020_4",
		[ENPC_BEGGAR] = "processEvent020_5",
		[ENPC_SHOPKEEP] = "processEvent020_6",
		[ENPC_PULMIA] = "processEvent030_2",
		[ENPC_CHARLYS] = "processEvent030_3",
		[ENPC_RSUSHMO] = "processEvent030_4",
		[ENPC_FRAILOISE] = "processEvent030_5",
		[ENPC_KIKICHUA] = "processEvent030_6",
		[ENPC_GERULF] = "processEvent030_7",
		[ENPC_HOBRIAUT] = "processEvent030_8",
		[ENPC_AENTFOET] = "processEvent030_9",
		[ENPC_PRUDENTIA] = "processEvent1000_1",
	},
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

local function helpingPulmia(quest)
	return quest:GetData():GetFlag(FLAG_PULMIA);
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
	if (sequence == SEQ_000 or sequence == SEQ_010) then
		quest:SetENpc(ENPC_PRUDENTIA, QFLAG_TALK);
		quest:SetENpc(ENPC_PULMIA, QFLAG_TALK);
	elseif (sequence == SEQ_015) then
		if (helpingPulmia(quest)) then
			quest:SetENpc(ENPC_PULMIA, QFLAG_TALK);
			quest:SetENpc(ENPC_PRUDENTIA);
		else
			quest:SetENpc(ENPC_PRUDENTIA, QFLAG_TALK);
			quest:SetENpc(ENPC_PULMIA);
		end
	elseif (sequence == SEQ_020) then
		quest:SetENpc(ENPC_ALLEY, QFLAG_PUSH, false, true);
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
	local isChef = (npcClassId == ENPC_PRUDENTIA or npcClassId == ENPC_PULMIA);

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_CHARLYS) then
		local accepted = delegate(player, quest, "processEventCharlysStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and isChef) then
		-- cul20010: the two chefs, and an order for thirty.
		delegate(player, quest, "processEvent010");
		quest:StartSequence(SEQ_010);
	elseif (seq == SEQ_010 and npcClassId == ENPC_PRUDENTIA) then
		-- Lend Prudentia a hand? (1 = yes)
		if (delegate(player, quest, "processEvent015") == 1) then
			quest:StartSequence(SEQ_015);
		end
	elseif (seq == SEQ_010 and npcClassId == ENPC_PULMIA) then
		-- Lend Pulmia a hand? (1 = yes)
		if (delegate(player, quest, "processEvent017") == 1) then
			quest:GetData():SetFlag(FLAG_PULMIA);
			quest:StartSequence(SEQ_015);
		end
	elseif (seq == SEQ_015 and isChef) then
		local chosen = ENPC_PRUDENTIA;
		if (helpingPulmia(quest)) then
			chosen = ENPC_PULMIA;
		end
		local bag = player:GetItemPackage(INVENTORY_NORMAL);
		if (npcClassId == chosen and bag:HasItem(ITEM_PIE_CRUST, 1)) then
			-- cul20020: the contest decided. It ends on an after-warp fade.
			delegate(player, quest, "processEvent020");
			bag:RemoveItem(ITEM_PIE_CRUST, 1);
			quest:StartSequence(SEQ_020);
			player:EndEvent();
			warpTo(player, LIMSA_ZONE, KITCHEN);
			return;
		elseif (chosen == ENPC_PRUDENTIA) then
			if (npcClassId == ENPC_PRUDENTIA) then
				delegate(player, quest, "processEvent015_2"); -- not yet
			else
				delegate(player, quest, "processEvent015_3");
			end
		else
			if (npcClassId == ENPC_PULMIA) then
				delegate(player, quest, "processEvent015_5"); -- not yet
			else
				delegate(player, quest, "processEvent015_4");
			end
		end
	elseif (TALKS[seq] ~= nil and TALKS[seq][npcClassId] ~= nil) then
		delegate(player, quest, TALKS[seq][npcClassId]);
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (npcClassId == ENPC_ALLEY and seq == SEQ_020) then
		-- cul20030: Prudentia behind the restaurant, and her thanks. It ends
		-- on an after-warp fade.
		delegate(player, quest, "processEvent030");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 2);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddGil(REWARD_GIL);
		player:CompleteQuest(quest);
		player:EndEvent();
		warpTo(player, LIMSA_ZONE, ALLEY);
		return;
	end
	player:EndEvent();
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_000) then
		return MRKR_CHEFS;
	elseif (seq == SEQ_010) then
		return MRKR_PRUDENTIA, MRKR_PULMIA;
	elseif (seq == SEQ_015) then
		if (helpingPulmia(quest)) then
			return MRKR_PULMIA;
		end
		return MRKR_PRUDENTIA;
	elseif (seq == SEQ_020) then
		return MRKR_ALLEY;
	end
end
