require ("global")
require ("quest")
require ("quests/spl/moonfire")

--[[

Quest Script

Name: 	Bombard Backlash
Code: 	Spl102
Id: 	110860
Prereq: The Heat Is On (Spl0i1, quest_offers.rs). Seasonal: Moonfire Faire
		(settings/events.toml).

The 2012 faire. See quests/spl/moonfire.lua for the story and the numbers.

The client's events (city argument 0 Limsa Lominsa, 1 Gridania, 2 Ul'dah):
processEventStartSea/Fst/Wil (the offer; arguments: already has the
uniform, the bag is full; 1 = signed up), processEventItemSelection (the
chaperone's list; returns 11-18 once the player confirms), NotEnough,
ItemPossession, FullCapacity, ItemTrade (a reward), QuestComplete, the
dancers' processEventBdanceBeforeOffer* and BdanceAfterOffer* (the fire
dance), and processEventNashuTalk. The site's cadet speaks Spl0i1's lines.

]]

local M = MOONFIRE;

SEQ_000				= 0;	-- Burst Bombards at the bomb sites; trade their ash.

FLAG_PENDING		= 0;	-- flags 0-2: a Bombard burst at site 0-2, ash not yet collected
FLAG_KING_PENDING	= 3;	-- flags 3-5: the same for the King Bombard
FLAG_DANCE_SEEN		= 6;	-- the fire dance was shown
COUNTER_KING		= 0;	-- counters 0-2: dances at site 0-2's King Bombard

local STARTS = {[0] = "processEventStartSea", [1] = "processEventStartFst", [2] = "processEventStartWil"};
local DANCES = {[0] = "processEventBdanceAfterOfferSea", [1] = "processEventBdanceAfterOfferFst", [2] = "processEventBdanceAfterOfferWil"};

local function event(player, quest, name, ...)
	return callClientFunction(player, "delegateEvent", player, quest, name, ...);
end

local function gearItem(player, i)
	return moonfireIsMale(player) and M.GEAR[i][1] or M.GEAR[i][2];
end

local function starterGear(player)
	local items = {};
	for _, i in ipairs(M.STARTER_GEAR) do
		table.insert(items, gearItem(player, i));
	end
	return items;
end

-- The bag is read before this event's AddItem lands, so the piece just
-- handed over (given) counts as owned.
local function hasTopGear(player, given)
	for _, i in ipairs(M.TOP_GEAR) do
		local item = gearItem(player, i);
		if (item ~= given and not moonfireBag(player):HasItem(item, 1)) then
			return false;
		end
	end
	return true;
end

-- The chaperone's list. Returns true when the quest is done.
local function chaperoneTalk(player, quest, city)
	local pick = event(player, quest, "processEventItemSelection", city, 0);
	if (type(pick) == "number") then
		pick = pick - M.GEAR_PICK_BASE;
	end
	local row = type(pick) == "number" and M.GEAR[pick] or nil;
	if (row == nil) then
		return false;
	end
	local item = gearItem(player, pick);
	if (pick ~= M.BLOOM and moonfireBag(player):HasItem(item, 1)) then
		event(player, quest, "processEventItemPossession", city);
	elseif (not moonfireBag(player):HasItem(M.BOMBARD_ASH, row[3])) then
		event(player, quest, "processEventNotEnough", city);
	else
		moonfireTake(player, {[M.BOMBARD_ASH] = row[3]});
		moonfireGive(player, {item});
		if (hasTopGear(player, item)) then
			event(player, quest, "processEventQuestComplete", city);
			event(player, quest, "processEventItemTrade", city);
			return true;
		end
		event(player, quest, "processEventItemTrade", city);
	end
	return false;
end

local function officerTalk(player, quest, city, site)
	local data = quest:GetData();
	local ash = 0;
	if (data:GetFlag(FLAG_PENDING + city)) then
		ash = ash + M.ASH_PER_BOMBARD;
		data:ClearFlag(FLAG_PENDING + city);
	end
	if (data:GetFlag(FLAG_KING_PENDING + city)) then
		ash = ash + M.ASH_PER_KING;
		data:ClearFlag(FLAG_KING_PENDING + city);
	end
	local spl0i1 = GetStaticActor("Spl0i1");
	if (ash > 0) then
		callClientFunction(player, "delegateEvent", player, spl0i1, "processEventSUMFESGAME001", 0, 1, site.variant);
		moonfireBag(player):AddItem(M.BOMBARD_ASH, ash, 1);
	else
		callClientFunction(player, "delegateEvent", player, spl0i1, "processEventSUMFESGAME002", site.variant);
	end
end

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	for city, c in pairs(M.CHAPERONES_2012) do
		quest:SetENpc(c, sequence == SEQ_ACCEPT and QFLAG_TALK or QFLAG_REWARD);
	end
	if (sequence == SEQ_ACCEPT) then
		return;
	end
	local data = quest:GetData();
	for city, c in pairs(M.DANCERS) do
		quest:SetENpc(c, data:GetFlag(FLAG_DANCE_SEEN) and QFLAG_NONE or QFLAG_TALK);
	end
	for city, s in pairs(M.SITES_2012) do
		local pending = data:GetFlag(FLAG_PENDING + city);
		local kingPending = data:GetFlag(FLAG_KING_PENDING + city);
		quest:SetENpc(s.officer, (pending or kingPending) and QFLAG_REWARD or QFLAG_NONE);
	end
	-- the Bombards answer the fire dance
	quest:SetENpc(M.BOMBARD_2012, QFLAG_NONE, false, false, true);
	quest:SetENpc(M.KING_2012, QFLAG_NONE, false, false, true);
end

function onTalk(player, quest, npc, eventName)
	local classId = npc:GetActorClassId();
	local cast = M.CAST[classId];

	if (quest:GetSequence() == SEQ_ACCEPT) then
		if (cast ~= nil and cast.role == "chaperone" and cast.year == 2012
			and IsSeasonalQuestOpen(quest:GetQuestId())) then
			local equipped = moonfireHasAny(player, starterGear(player));
			if (event(player, quest, STARTS[cast.city], equipped, false) == 1) then
				player:AcceptQuest(quest);
				if (not equipped) then
					moonfireGive(player, starterGear(player));
				end
			end
		elseif (cast ~= nil and cast.role == "dancer") then
			moonfireTalk(player, npc);
			return;
		end
		player:EndEvent();
		return;
	end

	local done = false;
	if (cast ~= nil and cast.role == "chaperone" and cast.year == 2012) then
		done = chaperoneTalk(player, quest, cast.city);
	elseif (cast ~= nil and cast.role == "dancer") then
		event(player, quest, DANCES[cast.city]);
		quest:GetData():SetFlag(FLAG_DANCE_SEEN);
	else
		local city, site = moonfireSite2012(player);
		if (site ~= nil and classId == site.officer) then
			officerTalk(player, quest, city, site);
		end
	end
	player:EndEvent();
	if (done) then
		player:CompleteQuest(quest);
	else
		quest:UpdateENPCs();
	end
end

-- A dance (/dance or the fire dance) at a Bombard bursts it; a Bombard King
-- takes three.
function onEmote(player, quest, npc, eventName)
	local classId = npc:GetActorClassId();
	local city, site = moonfireSite2012(player);
	local data = quest:GetData();
	-- Only the fire dance the Firedancers teach banishes a Bombard; the
	-- 2012 Bombards also answer a plain /dance (emoteDefault1), which just
	-- plays and does nothing for the quest.
	if (eventName == M.DANCE_EMOTE) then
		player:DoEmote(npc.Id, M.DANCE_DO_EMOTE, M.DANCE_MOTION);
	elseif (eventName == M.FIRE_DANCE_EVENT) then
		player:DoEmote(npc.Id, M.FIRE_DANCE_DO_EMOTE, M.FIRE_DANCE_MOTION);
	end
	if (eventName == M.FIRE_DANCE_EVENT and site ~= nil
		and (classId == M.BOMBARD_2012 or classId == M.KING_2012)) then
		if (classId == M.BOMBARD_2012) then
			data:SetFlag(FLAG_PENDING + city);
		else
			local n = data:GetCounter(COUNTER_KING + city) + 1;
			if (n >= M.KING_DANCES) then
				data:SetCounter(COUNTER_KING + city, 0);
				data:SetFlag(FLAG_KING_PENDING + city);
			else
				data:SetCounter(COUNTER_KING + city, n);
			end
		end
	end
	player:EndEvent();
	quest:UpdateENPCs();
end

function getJournalInformation(player, quest)
end

function getJournalMapMarkerList(player, quest)
end
