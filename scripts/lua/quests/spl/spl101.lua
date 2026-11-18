require ("global")
require ("quest")
require ("quests/spl/hatchingtide")

--[[

Quest Script

Name: 	Scrambled Eggs
Code: 	Spl101
Id: 	110859
Prereq: any city's Dreamer's Dilemma (quest_offers.rs). Seasonal: Hatching-tide
		(settings/events.toml).

Hatching-tide's second year. The spriggans stole the Dreamers' eggs again;
the Dreamer in each city (Jihli Aliapoh, Motte, Kikina) asks for them back
in sets of six: one fancy egg (Archon, colored, painted or darkened) and
five single-color eggs (red, blue, green, yellow, violet). What she gives
depends on the set: four egg rings for their recipes, last year's egg caps
for one egg of each color, a secret set that changes every Earth day, and
food and potions for the rest. A set she has no gift for hides an odd egg;
three odd eggs in the hatching pot (by the helper: Bricot, Fhlae, Wadard)
earn the Chocobo Egg Ring. Each city's spriggan thief (Twiggy, Iggy,
Ziggy) trades a motley egg, which stands in for any egg of a set.

The client's events: processEventEASTER_?1Start (the offer; ? is G, L or
U), processEvent000 (the Dreamer's menu; 3 = where are the eggs, 4 = I have
eggs), processEvent003 (an egg from the Dreamer, or not yet), the Spl101
askEgg widget (pick six eggs), processEvent005 (her song) then 005_3 or
005_1 (a gift), 005_2 (true: a cap you have, so something else; -1: the
set rule), 005_4 (an odd egg), processEvent000_1 (the helper; odd eggs in
the pot, and 1/2 for the ring not given / given), 000_6 (an egg into the
pot), 000_2 (the hint spriggan: up to 9 names a cave, 100 the thief),
000_5 (the thief; 0 trades the motley egg), and the *Start chatter. The
Gridania events have no suffix; Limsa Lominsa's end in _L, Ul'dah's in _U.

Our choices, where the client gives none: the Dreamer's egg once every
DREAMER_EGG_MINUTES (the client says ten Eorzean days; ten Eorzean hours
here), the secret sets and the gift table (from the 2012 event as players
recorded it), the gifts' day cycle (Earth days, server time), the helper
takes the three odd eggs at once (the server has no hatching pot), and the
quest finishes when all five rings are earned, so that the spriggans keep
dropping eggs until then (the 2012 quest finished at the first gift).

]]

local H = HATCHINGTIDE;

SEQ_000					= 0;	-- Recover the eggs and bring them in sets.

-- Quest flags: rings earned (0-4, in RINGS order), caps given (5-8)
FLAG_RING				= 0;
FLAG_CAP				= 5;
COUNTER_EGG				= 0;	-- minute stamp of the Dreamer's last egg

-- Eggs
MOTLEY_EGG				= 10012022;
ODD_EGG					= 10012023;
RED, BLUE, GREEN, YELLOW, VIOLET = 1, 2, 3, 4, 5;
COLOR_EGGS				= {10012024, 10012025, 10012026, 10012027, 10012028};	-- in the widget's order
FANCY_EGGS				= H.FANCY_EGGS;	-- Archon, colored, painted, darkened

DREAMER_EGG_MINUTES		= 30;	-- ten Eorzean hours (an Eorzean hour is 175 seconds)
DROP_FANCY_CHANCE		= 3;	-- one spriggan kill in this many leaves its fancy egg (else a colored one)
ODD_EGGS_FOR_RING		= 3;

-- Rings: the fancy egg (1-4) and the five colors each takes.
RINGS = {
	{ring = 9050058, fancy = 1, colors = {3, 0, 0, 2, 0}},	-- Pristine: Archon egg, 3 red, 2 yellow
	{ring = 9050061, fancy = 2, colors = {2, 1, 1, 1, 0}},	-- Vibrant: colored egg, 2 red, blue, green, yellow
	{ring = 9050060, fancy = 3, colors = {0, 3, 0, 1, 1}},	-- Brilliant: painted egg, 3 blue, yellow, violet
	{ring = 9050059, fancy = 4, colors = {2, 0, 1, 0, 2}},	-- Midnight: darkened egg, 2 red, green, 2 violet
};
CHOCOBO_RING			= 9050062;
FLAG_CHOCOBO_RING		= 4;

-- Last year's caps, for any fancy egg and one egg of each color.
CAPS = {H.PRISTINE_CAP, H.VIBRANT_CAP, H.BRILLIANT_CAP, H.MIDNIGHT_CAP};

-- The secret set (any fancy egg), one per Earth day in turn.
SECRET_SETS = {
	{0, 0, 3, 0, 2}, {3, 0, 2, 0, 0}, {2, 0, 1, 2, 0}, {2, 1, 0, 2, 0},
	{0, 2, 0, 3, 0}, {0, 3, 0, 1, 1}, {0, 2, 0, 0, 3}, {0, 0, 3, 0, 2},
	{2, 0, 2, 0, 1}, {2, 0, 2, 1, 0}, {3, 0, 0, 2, 0}, {0, 2, 0, 3, 0},
	{0, 3, 0, 1, 1}, {0, 2, 0, 0, 3},
};
-- Gifts, by the day of a three-day cycle: {item, count}.
SECRET_GIFTS = {{3020522, 3}, {3020516, 3}, {3020513, 3}};	-- Hi-potions of Intelligence, Vitality, Strength
PATTERN_GIFTS = {
	["5"]		= {{3020002, 4}, {3020002, 4}, {3020002, 4}},	-- Hi-potions
	["41"]		= {{3020521, 4}, {3020515, 4}, {3020512, 4}},	-- Potions of Intelligence, Vitality, Strength
	["32"]		= {{3010402, 10}, {3010010, 10}, {3010004, 10}},	-- Ginger Cookies, Shepherd's Pies, Dodo Omelettes
	["311"]		= {{3010401, 10}, {3010007, 10}, {3010003, 10}},	-- Apple Tarts, Rabbit Pies, Boiled Eggs
	["221"]		= {{3010412, 10}, {3010006, 10}, {3011015, 10}},	-- Bubble Chocolate, Marmot Steaks, Chicken Eggs
};
-- The rest ("2111" and "11111" once the cap is given) hide an odd egg.

-- Each city's event names.
CITY_EVENTS = {
	[H.CITIES.gridania]	= {start = "processEventEASTER_G1Start", sfx = "",
		helper = "processEventEASTER_G2Start", hint = "processEventEASTER_SP2Start", thief = "processEventEASTER_G_JStart"},
	[H.CITIES.limsa]	= {start = "processEventEASTER_L1Start", sfx = "_L",
		helper = "processEventEASTER_L2Start", hint = "processEventL_EASTER_SP2Start", thief = "processEventEASTER_L_JStart"},
	[H.CITIES.uldah]	= {start = "processEventEASTER_U1Start", sfx = "_U",
		helper = "processEventEASTER_U2Start", hint = "processEventU_EASTER_SP2Start", thief = "processEventEASTER_U_JStart"},
};

-- Spriggans: the fancy egg each kind leaves.
SPRIGGAN_FANCY = {
	[2106210] = 1,	-- shuffling: Archon egg
	[2106211] = 2,	-- scrambling: colored
	[2106212] = 3,	-- scurrying: painted
	[H.SPRINTING_SPRIGGAN] = 4,	-- sprinting: darkened
};

local function bag(player)
	return player:GetItemPackage(INVENTORY_NORMAL);
end

local function event(player, quest, name, ...)
	return callClientFunction(player, "delegateEvent", player, quest, name, ...);
end

local function today()
	return math.floor(os.time() / 86400);
end

-- "5", "41", "32", "311", "221", "2111" or "11111": the color counts, largest first.
local function pattern(colors)
	local c = {};
	for _, n in ipairs(colors) do
		if (n > 0) then
			table.insert(c, n);
		end
	end
	table.sort(c, function(a, b) return a > b; end);
	return table.concat(c);
end

local function sameColors(a, b)
	for i = 1, 5 do
		if (a[i] ~= b[i]) then
			return false;
		end
	end
	return true;
end

-- What a set earns: {kind, item, count, ...}. `fancy` is 1-4; `colors`
-- the five counts. Best first: a ring not yet earned, the day's secret
-- set, last year's cap, then the table.
local function judge(data, player, fancy, colors)
	for i, r in ipairs(RINGS) do
		if (r.fancy == fancy and sameColors(r.colors, colors) and not data:GetFlag(FLAG_RING + i - 1)) then
			return {kind = "ring", item = r.ring, count = 1, ring = i, rank = 1};
		end
	end
	local day = today();
	if (sameColors(SECRET_SETS[day % #SECRET_SETS + 1], colors)) then
		local g = SECRET_GIFTS[day % 3 + 1];
		return {kind = "gift", item = g[1], count = g[2], rank = 2};
	end
	local p = pattern(colors);
	if (p == "11111") then
		if (not data:GetFlag(FLAG_CAP + fancy - 1) and not bag(player):HasItem(CAPS[fancy], 1)) then
			return {kind = "cap", item = CAPS[fancy], count = 1, cap = fancy, rank = 3};
		end
		return {kind = "had", item = ODD_EGG, count = 1, rank = 9};
	end
	local g = PATTERN_GIFTS[p];
	if (g ~= nil) then
		g = g[day % 3 + 1];
		local rank = ({["5"] = 4, ["41"] = 5, ["32"] = 6, ["311"] = 7, ["221"] = 8})[p];
		return {kind = "gift", item = g[1], count = g[2], rank = rank};
	end
	return {kind = "odd", item = ODD_EGG, count = 1, rank = 10};
end

-- The six eggs the widget picked: the fancy egg id (0: none), the five
-- color counts, and whether the motley egg is among them. Returns the
-- best result over every egg the motley egg could stand for, or nil when
-- the set breaks the rule (or the eggs aren't in the bag).
local function weighSet(data, player, fancyId, colors, motley)
	local b = bag(player);
	local total = 0;
	for i = 1, 5 do
		colors[i] = tonumber(colors[i]) or 0;
		total = total + colors[i];
		if (colors[i] > 0 and not b:HasItem(COLOR_EGGS[i], colors[i])) then
			return nil;
		end
	end
	local fancy = 0;
	for i, id in ipairs(FANCY_EGGS) do
		if (id == fancyId) then
			fancy = i;
		end
	end
	if (fancy > 0 and not b:HasItem(fancyId, 1)) then
		return nil;
	end
	if (motley and not b:HasItem(MOTLEY_EGG, 1)) then
		return nil;
	end
	if (total + (fancy > 0 and 1 or 0) + (motley and 1 or 0) ~= 6) then
		return nil;
	end

	local best = nil;
	local function try(f, c)
		local r = judge(data, player, f, c);
		if (best == nil or r.rank < best.rank) then
			best = r;
		end
	end
	if (fancy > 0 and not motley) then
		if (total ~= 5) then return nil; end
		try(fancy, colors);
	elseif (fancy == 0 and motley) then
		if (total ~= 5) then return nil; end
		for f = 1, 4 do try(f, colors); end
	elseif (fancy > 0 and motley) then
		if (total ~= 4) then return nil; end
		for i = 1, 5 do
			local c = {colors[1], colors[2], colors[3], colors[4], colors[5]};
			c[i] = c[i] + 1;
			try(fancy, c);
		end
	else
		return nil;
	end
	best.fancyId = fancyId;
	best.colors = colors;
	best.motley = motley;
	return best;
end

local function takeSet(player, set)
	local b = bag(player);
	for i = 1, 5 do
		if (set.colors[i] > 0) then
			b:RemoveItem(COLOR_EGGS[i], set.colors[i]);
		end
	end
	if (set.fancyId ~= nil and set.fancyId ~= 0) then
		b:RemoveItem(set.fancyId, 1);
	end
	if (set.motley) then
		b:RemoveItem(MOTLEY_EGG, 1);
	end
end

local function allRings(data)
	for i = 0, 4 do
		if (not data:GetFlag(FLAG_RING + i)) then
			return false;
		end
	end
	return true;
end

local function finishIfDone(player, quest, data)
	if (allRings(data)) then
		player:CompleteQuest(quest);
		return true;
	end
	return false;
end

-- "I have eggs": the widget, then her song and the gift.
local function tradeSet(player, quest, ev, data)
	local fancyId, r, bl, g, y, v, motley, ok = event(player, quest, "askEgg");
	if (not (ok == true or ok == 1)) then
		return;
	end
	local set = weighSet(data, player, fancyId, {r, bl, g, y, v}, motley == true or motley == 1);
	if (set == nil) then
		event(player, quest, "processEvent005_2" .. ev.sfx, -1);
		return;
	end
	takeSet(player, set);
	event(player, quest, "processEvent005" .. ev.sfx);
	if (set.kind == "ring") then
		event(player, quest, "processEvent005_3" .. ev.sfx);
		data:SetFlag(FLAG_RING + set.ring - 1);
	elseif (set.kind == "cap") then
		event(player, quest, "processEvent005_1" .. ev.sfx);
		data:SetFlag(FLAG_CAP + set.cap - 1);
	elseif (set.kind == "had") then
		event(player, quest, "processEvent005_2" .. ev.sfx, true);
	elseif (set.kind == "odd") then
		event(player, quest, "processEvent005_4" .. ev.sfx);
	else
		event(player, quest, "processEvent005_1" .. ev.sfx);
	end
	bag(player):AddItem(set.item, set.count, 1);
end

local function dreamerTalk(player, quest, ev, data)
	local choice = event(player, quest, "processEvent000" .. ev.sfx);
	if (choice == 3) then
		local elapsed = (math.floor(os.time() / 60) - data:GetCounter(COUNTER_EGG)) % 65536;
		if (elapsed >= DREAMER_EGG_MINUTES) then
			event(player, quest, "processEvent003" .. ev.sfx, 0);
			local all = {FANCY_EGGS[1], FANCY_EGGS[2], FANCY_EGGS[3], FANCY_EGGS[4]};
			for _, e in ipairs(COLOR_EGGS) do table.insert(all, e); end
			bag(player):AddItem(all[math.random(#all)], 1, 1);
			data:SetCounter(COUNTER_EGG, math.floor(os.time() / 60) % 65536);
		else
			event(player, quest, "processEvent003" .. ev.sfx, 1);
		end
	elseif (choice == 4) then
		tradeSet(player, quest, ev, data);
	end
end

-- The helper: three odd eggs go into the hatching pot for the Chocobo Egg Ring.
local function helperTalk(player, quest, ev, data)
	local given = data:GetFlag(FLAG_RING + FLAG_CHOCOBO_RING);
	if (not given and bag(player):HasItem(ODD_EGG, ODD_EGGS_FOR_RING)) then
		for i = 1, ODD_EGGS_FOR_RING do
			event(player, quest, "processEvent000_6" .. ev.sfx, true);
		end
		bag(player):RemoveItem(ODD_EGG, ODD_EGGS_FOR_RING);
		event(player, quest, "processEvent000_1" .. ev.sfx, ODD_EGGS_FOR_RING, 1);
		bag(player):AddItem(CHOCOBO_RING, 1, 1);
		data:SetFlag(FLAG_RING + FLAG_CHOCOBO_RING);
		return;
	end
	event(player, quest, "processEvent000_1" .. ev.sfx, 0, given and 2 or 1);
end

local function hintTalk(player, quest, ev)
	local caves = {3, 5, 7, 9, 100};
	event(player, quest, "processEvent000_2" .. ev.sfx, caves[math.random(#caves)]);
end

local function thiefTalk(player, quest, ev)
	if (bag(player):HasItem(MOTLEY_EGG, 1)) then
		event(player, quest, "processEvent000_5" .. ev.sfx, 1, 0, 0);
	else
		event(player, quest, "processEvent000_5" .. ev.sfx, 0, 0, 0);
		bag(player):AddItem(MOTLEY_EGG, 1, 1);
	end
end

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	for city, _ in pairs(CITY_EVENTS) do
		if (sequence == SEQ_ACCEPT) then
			quest:SetENpc(city.dreamer, QFLAG_TALK);
		else
			quest:SetENpc(city.dreamer, QFLAG_REWARD);
			quest:SetENpc(city.helper);
			quest:SetENpc(city.hint);
			quest:SetENpc(city.thief);
		end
	end
end

function onTalk(player, quest, npc, eventName)
	local cast = H.CAST[npc:GetActorClassId()];
	if (cast == nil) then
		player:EndEvent();
		return;
	end
	local ev = CITY_EVENTS[cast.city];

	if (quest:GetSequence() == SEQ_ACCEPT) then
		if (cast.role == "dreamer" and IsSeasonalQuestOpen(quest:GetQuestId())
			and event(player, quest, ev.start) == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	end

	-- One copy of the quest data for the whole talk: SetFlag updates this
	-- copy at once, the stored one only after the talk.
	local data = quest:GetData();
	if (cast.role == "dreamer") then
		dreamerTalk(player, quest, ev, data);
	elseif (cast.role == "helper") then
		helperTalk(player, quest, ev, data);
	elseif (cast.role == "hint") then
		hintTalk(player, quest, ev);
	elseif (cast.role == "thief") then
		thiefTalk(player, quest, ev);
	end
	player:EndEvent();
	if (not finishIfDone(player, quest, data)) then
		quest:UpdateENPCs();
	end
end

-- Spriggans leave eggs: now and then their fancy egg, otherwise a colored one.
function onKillBNpc(player, quest, bnpc)
	local fancy = SPRIGGAN_FANCY[bnpc];
	if (fancy == nil) then
		return;
	end
	if (math.random(DROP_FANCY_CHANCE) == 1) then
		bag(player):AddItem(FANCY_EGGS[fancy], 1, 1);
	else
		bag(player):AddItem(COLOR_EGGS[math.random(#COLOR_EGGS)], 1, 1);
	end
end

function getJournalInformation(player, quest)
end

function getJournalMapMarkerList(player, quest)
end
