require ("global")
require ("quest")
require ("dungeon")

--[[

Quest Script (shared by the three nations)

Name: 	It Kills with Fire
Code: 	Gcl101 / Gcg101 / Gcu101
Id: 	111416 / 111616 / 111816
Prereq: Grand Company rank Private Third Class, level 25 (company_gate in quest_offers.rs).

Each nation's officer sends you to Louisoix Leveilleur of the Circle of
Knowing at Apkallus Falls in Gridania, who would bring down Ifrit. He has
you take an echo crystal of each element from six fierce beasts: Barometz
and Slippery Sykes by Camp Bloodshore, the nest commander and Pyrausta by
Camp Horizon, Queen Bolete and the jackanapes by Camp Tranquil. Merged,
the crystals make a Harmonizing Crystal that opens his aetherial gate to the
Bowl of Embers, but Ifrit only answers the Inferno Flambeau, held by the
Amalj'aa Voidtongue Ahzabb Chah in his cave near Nophica's Wells. With it,
Louisoix sends you through the gate. Ifrit falls, then Nael van Darnus,
Legatus of the VIIth, appears with a warning of the crimson star, and
Louisoix brings you back. Your officer hears it all.

The client runs one script for all three quests (Gcl101; Gcg101 and Gcu101
are empty stubs), with an opening and a closing event per nation. Each
nation's quest script sets NATION and loads this one. Louisoix already
stands at the falls; seed 142 adds the two missing beasts and Ifrit, and the
battle runs as content (dungeon.lua "embers", director
InstanceRaidLesserIfrit).

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Travel to Apkallus Falls and find Louisoix.
SEQ_010	= 10;	-- Obtain an echo crystal of each element.
SEQ_020	= 20;	-- Report to Louisoix.
SEQ_030	= 30;	-- Take the Inferno Flambeau from Voidtongue Ahzabb Chah.
SEQ_035	= 35;	-- Report to Louisoix.
SEQ_040	= 40;	-- Speak to Louisoix to face Ifrit.
SEQ_050	= 50;	-- Report to Louisoix (set by the battle's director).
SEQ_060	= 60;	-- Report to your officer.

-- Quest Actors
OFFICERS = {
	[1] = { id = 1500199, start = "processEventGuincumStart", finish = "processEvent_080_L", company = 1 },	-- Guincum, the Maelstrom
	[2] = { id = 1500200, start = "processEventFulkeStart",   finish = "processEvent_080_G", company = 2 },	-- Fulke, the Order of the Twin Adder
	[3] = { id = 1500198, start = "processEventAubreyStart",  finish = "processEvent_080_U", company = 3 },	-- Aubrey, the Immortal Flames
};
LOUISOIX				= 1060022;

-- The six beasts (battle npc classes) and their echo crystals (key items).
-- Each has a quest flag once its crystal is taken.
BEASTS = {
	{ class = 2102718, crystal = 11000413, flag = 0 },	-- Barometz, wind
	{ class = 2104212, crystal = 11000414, flag = 1 },	-- Slippery Sykes, water
	{ class = 2103005, crystal = 11000415, flag = 2 },	-- the nest commander, earth
	{ class = 2100114, crystal = 11000416, flag = 3 },	-- Pyrausta, lightning
	{ class = 2105915, crystal = 11000417, flag = 4 },	-- Queen Bolete, ice
	{ class = 2100510, crystal = 11000418, flag = 5 },	-- the jackanapes, fire
};
AHZABB_CHAH				= 2162061;	-- Voidtongue Ahzabb Chah

-- Key items
INFERNO_FLAMBEAU		= 11000419;
HARMONIZING_CRYSTAL		= 11000420;

-- Facing Ifrit: a party of four Disciples of War or Magic at level 25, as the
-- briefing tells it. The server has no party state for scripts yet, so only
-- the level and the discipline are checked.
ENTRY_LEVEL				= 25;
RAID_CONTENT			= 4;		-- the Bowl of Embers in the client's raid list (its entry prompt)

-- Rewards (the client's reward sheet rows: EXP tier 8 in slot 1, seals in
-- slot 5: 1000, or 1500 when the party was all of your company)
REWARD_EXP				= 1760;
REWARD_SEALS			= 1000;

local function officer()
	return OFFICERS[NATION];
end

-- A flag set in this hook doesn't read back until it ends, so the beast
-- just slain counts as taken.
local function crystalsTaken(quest, slain)
	for _, beast in ipairs(BEASTS) do
		if (beast ~= slain and not quest:GetData():GetFlag(beast.flag)) then
			return false;
		end
	end
	return true;
end

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	local officerId = officer().id;
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(officerId, QFLAG_TALK);
	elseif (sequence == SEQ_000 or sequence == SEQ_020 or sequence == SEQ_035
			or sequence == SEQ_040 or sequence == SEQ_050) then
		quest:SetENpc(LOUISOIX, QFLAG_TALK);
		quest:SetENpc(officerId);
	elseif (sequence == SEQ_010 or sequence == SEQ_030) then
		quest:SetENpc(LOUISOIX);
		quest:SetENpc(officerId);
	elseif (sequence == SEQ_060) then
		quest:SetENpc(officerId, QFLAG_REWARD);
		quest:SetENpc(LOUISOIX);
	end
end

-- Only Disciples of War or Magic at the entry level face Ifrit.
local function mayEnter(player)
	return (player:IsDiscipleOfWar() or player:IsDiscipleOfMagic())
		and player:GetHighestLevel() >= ENTRY_LEVEL;
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();
	local o = officer();

	if (sequence == SEQ_ACCEPT and classId == o.id) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, o.start, 0, 0);
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (sequence < SEQ_060 and classId == o.id) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_000", NATION);
	elseif (sequence == SEQ_000 and classId == LOUISOIX) then
		-- the Circle of Knowing, the primals' hunger, and the six beasts
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010", NATION);
		quest:StartSequence(SEQ_010);
	elseif (sequence == SEQ_010 and classId == LOUISOIX) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010_1");
	elseif (sequence == SEQ_020 and classId == LOUISOIX) then
		-- the aetherial gate, the Harmonizing Crystal, and the flambeau
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_030");
		for _, beast in ipairs(BEASTS) do
			player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(beast.crystal, 1);
		end
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(HARMONIZING_CRYSTAL, 1, 1);
		quest:StartSequence(SEQ_030);
	elseif (sequence == SEQ_030 and classId == LOUISOIX) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_030_1");
	elseif (sequence == SEQ_035 and classId == LOUISOIX) then
		-- his counsel: the party, the primal's taint, the time allowed
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_050");
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_050_1");
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_050_2");
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_050_3");
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_050_6");
		quest:StartSequence(SEQ_040);
	elseif (sequence == SEQ_040 and classId == LOUISOIX) then
		-- through the gate (the guide's own prompt)
		if (callClientFunction(player, "askEnterInstanceRaid", RAID_CONTENT)) then
			if (mayEnter(player)) then
				player:EndEvent();
				enterDungeon(player, "embers");
				return;
			end
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_060_NG");
		end
	elseif (sequence == SEQ_050 and classId == LOUISOIX) then
		-- the aether spilled, the White Raven, and Cid Garlond
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_070", NATION, 0);
		quest:StartSequence(SEQ_060);
	elseif (sequence == SEQ_060 and classId == LOUISOIX) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_070_1");
	elseif (sequence == SEQ_060 and classId == o.id) then
		-- the report, and what the Empire may have done to Dalamud
		callClientFunction(player, "delegateEvent", player, quest, o.finish, NATION);
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 5);
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(HARMONIZING_CRYSTAL, 1);
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(INFERNO_FLAMBEAU, 1);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddSeals(o.company, REWARD_SEALS);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

-- The six beasts each leave an echo crystal; the Voidtongue, the flambeau.
-- Ifrit's fall is the battle director's (InstanceRaidLesserIfrit).
function onKillBNpc(player, quest, bnpc)
	local sequence = quest:GetSequence();
	if (sequence == SEQ_010) then
		for _, beast in ipairs(BEASTS) do
			if (bnpc == beast.class and not quest:GetData():GetFlag(beast.flag)) then
				quest:GetData():SetFlag(beast.flag);
				player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(beast.crystal, 1, 1);
				if (crystalsTaken(quest, beast)) then
					quest:StartSequence(SEQ_020);
				end
				return;
			end
		end
	elseif (sequence == SEQ_030 and bnpc == AHZABB_CHAH) then
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(INFERNO_FLAMBEAU, 1, 1);
		quest:StartSequence(SEQ_035);
	end
end

function onPush(player, quest, npc)
	player:EndEvent();
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
