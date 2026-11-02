require ("global")
require ("quest")
require ("gcseals")

--[[

Quest Script (shared by the three nations)

Name: 	Patrol, Interrupted / Cure for the Common Pox / Mess with the Goat, Get the Horns
Code: 	Gcl702 / Gcg702 / Gcu702
Id: 	111434 / 111634 / 111834
Prereq: The company's Gc?701 (the promotion to Sergeant), a sworn member of
		the company (company_gate in quest_offers.rs), level 50, and the rank of
		Chief Sergeant: this is the officer's gate from 27 to 31 (tier_shift_quest
		in gc.rs).

The officer offers a petty officer the commission of officer, if they can
lead: hunt down a beast or a band that harries the company's patrols. The
Maelstrom sends you after a great buffalo by Mistbeard Cove, north-east of
Camp Bald Knoll; the Twin Adder after the goblin Haughtpox Bloatbelly and his
band north and east of Treespeak; the Immortal Flames after the elder
mosshorn and its aldgoats south-east of Nophica's Wells. Back at
headquarters the officer reads the report, and a salute makes you a Second
Lieutenant (rank 31) with a stipend of 5,000 seals and an Eorzean Alliance
commemorative coin.

Each nation runs its own client script, with the same event names (the
officer's name in two of them). Seed 190 adds the great buffalo; Haughtpox
and the elder mosshorns are already world monsters (seed 101). Retail asked for
the company's petty officer medal (bought with seals) before the offer; no
shop sells it here yet, so the rank of Chief Sergeant does as well. The
quest card says the quarry shows only in daylight (Eorzea time); here it is
always out.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Slay the quarry.
SEQ_005	= 5;	-- Report to your officer, then salute.

-- Flags
FLAG_REPORTED			= 0;	-- the officer has read the report; a salute promotes

-- Ranks
RANK_CHIEF_SERGEANT		= 27;	-- the rank the commission is offered at
RANK_SECOND_LIEUTENANT	= 31;

-- Rewards: the stipend the officer names (the client's text carries 5000),
-- the experience the quest card shows (~6,600) and the Eorzean Alliance
-- commemorative coin the officer awards in processEvent010.
REWARD_SEALS			= 5000;
REWARD_EXP				= 6600;
REWARD_COIN				= 10011251;

NATIONS = {
	[1] = {	-- the Maelstrom: the great buffalo by Mistbeard Cove
		officer = 1500199, name = "GUINCUM", medal = 2001028, company = 1,
		salute = { animId = 50, descId = 21427 },	-- Storm Salute (emote 146)
		quarry = { [2100801] = true },
	},
	[2] = {	-- the Order of the Twin Adder: Haughtpox Bloatbelly at Treespeak
		officer = 1500200, name = "FULKE", medal = 2001029, company = 2,
		salute = { animId = 51, descId = 21429 },	-- Serpent Salute (emote 147)
		quarry = { [2110312] = true },
	},
	[3] = {	-- the Immortal Flames: the elder mosshorn by Nophica's Wells
		officer = 1500198, name = "AUBREY", medal = 2001030, company = 3,
		salute = { animId = 52, descId = 21431 },	-- Flame Salute (emote 148)
		quarry = { [2102311] = true },
	},
};

local function nation()
	return NATIONS[NATION];
end

-- The medal is a key item; a Chief Sergeant's rank stands in while no shop sells it.
local function mayTakeQuest(player)
	local n = nation();
	return player:GetItemPackage(INVENTORY_KEYITEMS):HasItem(n.medal)
		or GetGCRank(player, n.company) >= RANK_CHIEF_SERGEANT;
end

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	local n = nation();
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(n.officer, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(n.officer);
	elseif (sequence == SEQ_005) then
		-- talk for the report; the salute is an emote at the officer
		quest:SetENpc(n.officer, QFLAG_REWARD, true, false, true);
	end
end

function onTalk(player, quest, npc)
	local n = nation();
	local sequence = quest:getSequence();
	if (npc:GetActorClassId() ~= n.officer) then
		player:EndEvent();
		return;
	end

	if (sequence == SEQ_ACCEPT) then
		if (not mayTakeQuest(player)) then
			callClientFunction(player, "delegateEvent", player, quest, "processEventHint");
		else
			local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventStart");
			if (accepted == 1) then
				player:AcceptQuest(quest, true);
			end
		end
	elseif (sequence == SEQ_000) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_" .. n.name);
	elseif (sequence == SEQ_005) then
		local data = quest:GetData();
		if (not data:GetFlag(FLAG_REPORTED)) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005");
			data:SetFlag(FLAG_REPORTED);
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005_" .. n.name);
		end
	end
	player:EndEvent();
	quest:UpdateENPCs();
end

-- The salute. Seed 190 gives each officer one emote condition, its
-- company's salute ("emoteDefault1"), so no other emote reaches here.
function onEmote(player, quest, npc, eventName)
	local n = nation();
	if (quest:getSequence() ~= SEQ_005 or npc:GetActorClassId() ~= n.officer
		or not quest:GetData():GetFlag(FLAG_REPORTED)) then
		player:EndEvent();
		return;
	end
	player:DoEmote(npc.Id, n.salute.animId, n.salute.descId);
	wait(2.5);
	local oldRank = GetGCRank(player, n.company);
	callClientFunction(player, "delegateEvent", player, quest, "processEvent010", oldRank);
	player:SetGCRank(n.company, RANK_SECOND_LIEUTENANT);
	player:AddSeals(n.company, REWARD_SEALS);
	player:GetItemPackage(INVENTORY_NORMAL):AddItem(REWARD_COIN, 1, 1);
	callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 5);
	player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
	player:EndEvent();
	player:CompleteQuest(quest);
end

function onKillBNpc(player, quest, classId)
	if (quest:getSequence() == SEQ_000 and nation().quarry[classId]) then
		quest:StartSequence(SEQ_005);
	end
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
