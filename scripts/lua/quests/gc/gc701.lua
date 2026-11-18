require ("global")
require ("quest")
require ("gcseals")
require ("modifiers")

--[[

Quest Script (shared by the three nations)

Name: 	The Weakest Link / You Don't Have the Rite / Gore a Lizard, Hurry
Code: 	Gcl701 / Gcg701 / Gcu701
Id: 	111428 / 111628 / 111828
Prereq: A sworn member of the company (company_gate in quest_offers.rs),
		level 45, and the rank of Corporal: this is the petty officer's gate
		from 17 to 21 (tier_shift_quest in gc.rs).

The officer sends a corporal to a commander in the field, who runs a War
Merit duty: alone, cut into a beastman camp and earn 1,000 War Merit before
the enemy rallies. The Maelstrom strikes the kobold encampment in Upper La
Noscea under Storm Sergeant Alain Brooks; the Twin Adder breaks the Ixal's
rite of passage in a North Shroud clearing under First Commander Vorsaile
Heuloix; the Immortal Flames hit the Amalj'aa supply camp by the altar in
Eastern Thanalan under First Commander Ashdale. The duty is entered in place
(SimpleContentGc?70101, QuestDirectorGc?70101). Back at headquarters the
officer hears the report, and a salute makes you a Sergeant Third Class
(rank 21).

Each nation runs its own client script with its own event names (EVENTS
below). Higher-ranked beastmen are worth more War Merit (MERIT); the camp is
seeded so that clearing it earns exactly 1,000, and the duty ends when the
last one falls. Retail's time limit is not modeled (the client's War Merit
and timer widget needs director work sync, which is a stub), nor is the
party check: you can't die in content yet, so KO doesn't fail it either.
Retail asked for the company's medal (Lapis Cross, Emerald Leaf, Gold
Scales) before the offer; no shop sells it here yet, so the rank of
Corporal does as well.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Report to the commander and complete the duty.
SEQ_005	= 5;	-- Report to your officer, then salute.

-- Flags
FLAG_BRIEFED			= 0;	-- the commander has explained the duty
FLAG_THANKED			= 1;	-- the commander has seen you off after the duty
FLAG_REPORTED			= 2;	-- the officer has heard the report; a salute promotes

-- Counters
CNTR_MERIT				= 0;	-- War Merit earned in the current attempt

-- Ranks
RANK_CORPORAL			= 17;	-- the rank the duty is offered at
RANK_SERGEANT_THIRD		= 21;

MERIT_GOAL				= 1000;

-- Rewards
REWARD_SEALS			= 2000;
REWARD_EXP				= 4400;

NATIONS = {
	[1] = {	-- the Maelstrom: the kobold encampment, Upper La Noscea
		questId = 111428, officer = 1500199, commander = 1001833, medal = 2001009, company = 1,
		salute = { animId = 50, descId = 21427 },	-- Storm Salute (emote 146)
		content = "Gcl70101", home = {135, -655.0, 66.3, -1650.0, -1.6},
		merit = { [2206606] = 100, [2206607] = 150, [2206608] = 300 },	-- cragsman, roundsman, bedesman
		events = {
			offer = "processEventStart", hint = "processEventHint", sent = "processEventStartAfter",
			brief = "processEventAlain", party = "processEventNG", ask = "processEventOK",
			abandon = "processEventExit", done = "processEventAlain2", doneAgain = "processEventAlainAfter",
			report = "processEventGuincum", reportAgain = "processEventGuincumAfter", promote = "processEventClear",
		},
	},
	[2] = {	-- the Order of the Twin Adder: the Ixali clearing, North Shroud
		questId = 111628, officer = 1500200, commander = 1001835, medal = 2001010, company = 2,
		salute = { animId = 51, descId = 21429 },	-- Serpent Salute (emote 147)
		content = "Gcg70101", home = {152, -1219.0, 35.1, -2244.0, -1.57},
		merit = { [2206409] = 100, [2206410] = 150, [2206411] = 300 },	-- limbcutter, soilseer, cloudwalker
		events = {
			offer = "processEventFULKEStart", hint = "processEventFULKEhint", sent = "processEventFULKEhint2",
			brief = "processEventVORSAILEStart", party = "processEventVORSAILEng", ask = "processEventVORSAILEok",
			abandon = "processEventVORSAILEstop", done = "processEventVORSAILEcomp", doneAgain = "processEventVORSAILEcomp2",
			report = "processEventFULKEevent", reportAgain = "processEventFULKEevent2", promote = "processEventFULKEend",
		},
	},
	[3] = {	-- the Immortal Flames: the Amalj'aa altar, Eastern Thanalan
		questId = 111828, officer = 1500198, commander = 1001834, medal = 2001011, company = 3,
		salute = { animId = 52, descId = 21431 },	-- Flame Salute (emote 148)
		content = "Gcu70101", home = {171, 1416.0, 247.8, 253.6, 1.57},
		merit = { [2206525] = 100, [2206526] = 150, [2206527] = 300 },	-- pennoncier, captain, high divinator
		events = {
			offer = "processEventStart", hint = "processEventAubreyHint", sent = "processEvent000_2",
			brief = "processEvent000", party = "processEvent005_2", ask = "processEvent005",
			abandon = "processEvent010", done = "processEvent015", doneAgain = "processEvent015_2",
			report = "processEvent020", reportAgain = "processEvent025_2", promote = "processEvent025",
		},
	},
};

local function nation()
	return NATIONS[NATION];
end

local function event(player, quest, name, ...)
	return callClientFunction(player, "delegateEvent", player, quest, nation().events[name], ...);
end

-- The medal is a key item; a Corporal's rank stands in while no shop sells it.
local function mayTakeQuest(player)
	local n = nation();
	return player:GetItemPackage(INVENTORY_KEYITEMS):HasItem(n.medal)
		or GetGCRank(player, n.company) >= RANK_CORPORAL;
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
		quest:SetENpc(n.commander, QFLAG_TALK);
	elseif (sequence == SEQ_005) then
		quest:SetENpc(n.commander);
		-- talk for the report; the salute is an emote at the officer
		quest:SetENpc(n.officer, QFLAG_REWARD, true, false, true);
	end
end

function onTalk(player, quest, npc)
	local n = nation();
	local sequence = quest:getSequence();
	local classId = npc:GetActorClassId();
	local data = quest:GetData();

	if (classId == n.officer) then
		if (sequence == SEQ_ACCEPT) then
			if (not mayTakeQuest(player)) then
				event(player, quest, "hint");
			elseif (event(player, quest, "offer") == 1) then
				player:AcceptQuest(quest, true);
			end
		elseif (sequence == SEQ_000) then
			event(player, quest, "sent");
		elseif (sequence == SEQ_005) then
			if (not data:GetFlag(FLAG_REPORTED)) then
				event(player, quest, "report");
				data:SetFlag(FLAG_REPORTED);
			else
				event(player, quest, "reportAgain");
			end
		end
	elseif (classId == n.commander) then
		if (sequence == SEQ_000 and player:GetDirector() ~= nil) then
			-- in the duty: the commander offers to call it off
			if (event(player, quest, "abandon") == 1) then
				abandonGc701Content(player, quest);
				return;
			end
		elseif (sequence == SEQ_000) then
			if (not data:GetFlag(FLAG_BRIEFED)) then
				event(player, quest, "brief");
				data:SetFlag(FLAG_BRIEFED);
			end
			if (event(player, quest, "ask") == 1) then
				startGc701Content(player, quest);
				return;
			end
		elseif (sequence == SEQ_005) then
			if (not data:GetFlag(FLAG_THANKED)) then
				event(player, quest, "done");
				data:SetFlag(FLAG_THANKED);
			else
				event(player, quest, "doneAgain");
			end
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
	event(player, quest, "promote", oldRank);
	player:SetGCRank(n.company, RANK_SERGEANT_THIRD);
	player:AddSeals(n.company, REWARD_SEALS);
	callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 5);
	player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
	player:EndEvent();
	player:CompleteQuest(quest);
end

-- War Merit. These beastmen spawn only in the duty (the kill hook's player
-- carries no director to check). The director ends the duty once the camp
-- is cleared.
function onKillBNpc(player, quest, classId)
	local worth = nation().merit[classId];
	if (quest:getSequence() ~= SEQ_000 or worth == nil) then
		return;
	end
	local data = quest:GetData();
	local merit = math.min(data:GetCounter(CNTR_MERIT) + worth, MERIT_GOAL);
	data:SetCounter(CNTR_MERIT, merit);
	player:SendMessage(0x20, "", string.format("War Merit: %d / %d", merit, MERIT_GOAL));
end

-- The camp, a duty entered in place (spawnType 0x16).
function startGc701Content(player, quest)
	local n = nation();
	quest:GetData():SetCounter(CNTR_MERIT, 0);
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent",
		n.content, "SimpleContent" .. n.content, "Quest/QuestDirector" .. n.content);
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

-- The duty's director (QuestDirectorGc?70101). The entry kick raises the
-- loading veil even in place, so it is lifted and the kick closed. Once the
-- camp is cleared you are set down by the commander with word for the officer.
function runGc701Director(player, actor)
	local n = nation();
	local quest = player:GetQuest(n.questId);

	-- questBaseRewardSeting is the client's call that lifts the veil.
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A duty that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	quest:StartSequence(SEQ_005);
	attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
	player:EndEvent();
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	GetWorldManager():DoZoneChange(player, n.home[1], nil, 0, 15,
		n.home[2], n.home[3], n.home[4], n.home[5]);
end

-- Called off at the commander: the merit is lost and you are set down where you stand.
function abandonGc701Content(player, quest)
	quest:GetData():SetCounter(CNTR_MERIT, 0);
	player:EndEvent();
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	GetWorldManager():DoZoneChange(player, player:GetZoneID(), nil, 0, 15,
		player.positionX, player.positionY, player.positionZ, player.rotation);
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
