require ("global")
require ("quest")

--[[

Quest Script

Name:	Something in the Soup
Code:	Cul306
Id:	110442
Prereq: Level 36, Culinarian

Prudentia has a proposition; while she talks, Pulmia slips off to meet a
suitor and a young man comes asking after her (processEventPrudentiaStart =
cul30610 with "Assist Prudentia?", 1 = accepted, after-warp fade). The Echo
on Prudentia (processEvent020, cul30620) shows her past with the young
man; asked about him, she storms out and Charlys sends you after her
(cul30630). At the bethel overlooking Galadion Bay she remembers their
first meeting (cul30640), and the Echo there (processEvent050, cul30650)
shows her poisoning Pulmia's soup for the suitor; she runs off to stop
them and asks you to cook a devilbelly meatball as the antidote. With the
meatball you find her near the Bismarck (cul30660), and at the bethel the
whole tangle comes out (cul30665). Charlys explains and pays you
(cul30670): 36,000 gil and 3,600 experience, like the other level-36 guild
quests.

Prudentia has no actor outside the kitchen, so the bethel and the spot near
the Bismarck are push circles. The meatball is a crafted good (a quest
recipe, like the foulbelly meatball it is made from; three cooks hand over
the odd ingredients): the circle does nothing until it is in the bag.

Journal: steps 58-65 of the Limsa Lominsa quest journal sheet.

]]

-- Sequence Numbers
SEQ_000	= 0;   -- The Echo on Prudentia.
SEQ_010	= 10;  -- Ask Prudentia about the young man.
SEQ_030	= 30;  -- Find her by the bay.
SEQ_040	= 40;  -- The Echo at the bethel.
SEQ_050	= 50;  -- Cook a devilbelly meatball and find Prudentia.
SEQ_060	= 60;  -- Catch up with Pulmia and her suitor.
SEQ_065	= 65;  -- Speak with Charlys.

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
ENPC_BETHEL		= 1091126; -- push circle at the bethel
ENPC_OUTSIDE	= 1091127; -- push circle where Prudentia waits near the Bismarck

-- Items
ITEM_MEATBALL	= 11000071; -- Devilbelly Meatball
ITEM_DEVILSHROOM	= 11000072;
ITEM_QUEER_MEAT		= 11000074; -- Queer-smelling Meat
ITEM_SWEET_SPICE	= 11000075; -- Sweet-smelling Spice

-- While you cook the antidote (SEQ_050) three cooks hand over the odd
-- ingredients once each (journal: ask the guild's other culinarians); the
-- foulbelly and devilbelly meatballs are quest recipes
-- (questrecipes/cul.lua), with a button mushroom from the market.
GIVES = {
	[ENPC_GERULF] = { flag = 0, item = ITEM_QUEER_MEAT, qty = 1 },
	[ENPC_FRAILOISE] = { flag = 1, item = ITEM_SWEET_SPICE, qty = 1 },
	[ENPC_HLAHONO] = { flag = 2, item = ITEM_DEVILSHROOM, qty = 2 },
};

-- Quest Markers (each names its scene in the client's marker index)
MRKR_ECHO			= 11044202;
MRKR_STORMS_OUT		= 11044203;
MRKR_BETHEL			= 11044204;
MRKR_BETHEL_ECHO	= 11044205;
MRKR_OUTSIDE		= 11044206;
MRKR_LOVERS			= 11044207;
MRKR_CHARLYS		= 11044208;

REWARD_GIL	= 36000;
REWARD_EXP	= 3600;

-- Scenes that end on an after-warp fade set you down here (Limsa Lominsa
-- upper decks; town cut frames are offset from server coordinates, so these
-- are estimates).
LIMSA_ZONE = 230;
KITCHEN = { -508.4, 42.3, 37.6, 0.48 }; -- in front of Prudentia's station
CHARLYS_DESK = { -512.2, 42.3, 30.7, 2.77 };
BETHEL = { -596.0, 6.0, 60.0, 0.9 }; -- beside the bethel circle

-- What the cooks say between steps. The client script names no speaker;
-- these follow the lines' content.
KITCHEN_TALK = {
	[ENPC_RSUSHMO] = "processEvent010_3",
	[ENPC_AENTFOET] = "processEvent010_4",
	[ENPC_GERULF] = "processEvent010_5",
	[ENPC_HOBRIAUT] = "processEvent010_6",
	[ENPC_FRAILOISE] = "processEvent010_7",
};
TALKS = {
	[SEQ_000] = KITCHEN_TALK,
	[SEQ_010] = KITCHEN_TALK,
	[SEQ_030] = {
		[ENPC_CHARLYS] = "processEvent030_2",
		[ENPC_RSUSHMO] = "processEvent030_3",
		[ENPC_AENTFOET] = "processEvent030_4",
		[ENPC_KIKICHUA] = "processEvent030_5",
		[ENPC_HOBRIAUT] = "processEvent030_6",
		[ENPC_FRAILOISE] = "processEvent030_7",
		[ENPC_GERULF] = "processEvent030_8",
	},
	[SEQ_050] = {
		[ENPC_CHARLYS] = "processEvent050_2",
		[ENPC_RSUSHMO] = "processEvent050_3",
		[ENPC_GERULF] = "processEvent050_4",
		[ENPC_HOBRIAUT] = "processEvent050_5",
		[ENPC_HLAHONO] = "processEvent050_6",
		[ENPC_KIKICHUA] = "processEvent050_7",
		[ENPC_FRAILOISE] = "processEvent050_8",
	},
	[SEQ_065] = {
		[ENPC_PRUDENTIA] = "processEvent065_2",
		[ENPC_PULMIA] = "processEvent065_3",
		[ENPC_GERULF] = "processEvent065_4",
		[ENPC_AENTFOET] = "processEvent065_5",
		[ENPC_FRAILOISE] = "processEvent065_6",
		[ENPC_HOBRIAUT] = "processEvent065_7",
		[ENPC_RSUSHMO] = "processEvent065_8",
		[ENPC_HLAHONO] = "processEvent065_9",
	},
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_PRUDENTIA, QFLAG_TALK);
		return;
	end
	if (TALKS[sequence] ~= nil) then
		for classId, _ in pairs(TALKS[sequence]) do
			quest:SetENpc(classId);
		end
	end
	if (sequence == SEQ_000 or sequence == SEQ_010) then
		quest:SetENpc(ENPC_PRUDENTIA, QFLAG_TALK);
	elseif (sequence == SEQ_030 or sequence == SEQ_040 or sequence == SEQ_060) then
		quest:SetENpc(ENPC_BETHEL, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_050) then
		quest:SetENpc(ENPC_OUTSIDE, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_065) then
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

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_PRUDENTIA) then
		-- cul30610: 1 = accepted, and the scene ends on an after-warp fade.
		local accepted = delegate(player, quest, "processEventPrudentiaStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
			player:EndEvent();
			warpTo(player, LIMSA_ZONE, KITCHEN);
			return;
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and npcClassId == ENPC_PRUDENTIA) then
		-- The Echo on Prudentia (cul30620). Turning it down leaves her be.
		if (delegate(player, quest, "processEvent020") == 1) then
			quest:StartSequence(SEQ_010);
		end
	elseif (seq == SEQ_010 and npcClassId == ENPC_PRUDENTIA) then
		-- cul30630: she storms out; Charlys sends you after her. It ends on
		-- an after-warp fade.
		delegate(player, quest, "processEvent030");
		quest:StartSequence(SEQ_030);
		player:EndEvent();
		warpTo(player, LIMSA_ZONE, CHARLYS_DESK);
		return;
	elseif (seq == SEQ_065 and npcClassId == ENPC_CHARLYS) then
		-- cul30670: Charlys explains, and pays you. It ends on an after-warp
		-- fade.
		delegate(player, quest, "processEvent070");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 2);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddGil(REWARD_GIL);
		player:CompleteQuest(quest);
		player:EndEvent();
		warpTo(player, LIMSA_ZONE, CHARLYS_DESK);
		return;
	elseif (TALKS[seq] ~= nil and TALKS[seq][npcClassId] ~= nil) then
		delegate(player, quest, TALKS[seq][npcClassId]);
		local give = GIVES[npcClassId];
		if (seq == SEQ_050 and give ~= nil and not quest:GetData():GetFlag(give.flag)) then
			player:GetItemPackage(INVENTORY_NORMAL):AddItem(give.item, give.qty, 1);
			quest:GetData():SetFlag(give.flag);
		end
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (npcClassId == ENPC_BETHEL and seq == SEQ_030) then
		-- cul30640: where she first met him.
		delegate(player, quest, "processEvent040");
		quest:StartSequence(SEQ_040);
	elseif (npcClassId == ENPC_BETHEL and seq == SEQ_040) then
		-- The Echo at the bethel (cul30650): the poisoned soup. 1 = seen;
		-- it then ends on an after-warp fade.
		if (delegate(player, quest, "processEvent050") == 1) then
			quest:StartSequence(SEQ_050);
			player:EndEvent();
			warpTo(player, LIMSA_ZONE, BETHEL);
			return;
		end
	elseif (npcClassId == ENPC_OUTSIDE and seq == SEQ_050) then
		local bag = player:GetItemPackage(INVENTORY_NORMAL);
		if (bag:HasItem(ITEM_MEATBALL, 1)) then
			-- cul30660: the meatball for Prudentia, and off after Pulmia.
			-- It ends on an after-warp fade, set down by the bethel.
			delegate(player, quest, "processEvent060");
			bag:RemoveItem(ITEM_MEATBALL, 1);
			quest:StartSequence(SEQ_060);
			player:EndEvent();
			warpTo(player, LIMSA_ZONE, BETHEL);
			return;
		end
	elseif (npcClassId == ENPC_BETHEL and seq == SEQ_060) then
		-- cul30665: Pulmia, Lienart and Adela.
		delegate(player, quest, "processEvent065");
		quest:StartSequence(SEQ_065);
	end
	quest:UpdateENPCs();
	player:EndEvent();
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_000) then
		return MRKR_ECHO;
	elseif (seq == SEQ_010) then
		return MRKR_STORMS_OUT;
	elseif (seq == SEQ_030) then
		return MRKR_BETHEL;
	elseif (seq == SEQ_040) then
		return MRKR_BETHEL_ECHO;
	elseif (seq == SEQ_050) then
		return MRKR_OUTSIDE;
	elseif (seq == SEQ_060) then
		return MRKR_LOVERS;
	elseif (seq == SEQ_065) then
		return MRKR_CHARLYS;
	end
end
