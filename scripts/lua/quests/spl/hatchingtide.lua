--[[

Hatching-tide: the numbers and ids the Dreamer's quests share, kept in one
place so they are easy to change.

When the event runs:  settings/events.toml ([hatchingtide]), or `!event`.
Where its NPCs stand: common/sql/data/server_spawn_locations.sql,
                      ids 31250-31261 (tagged in server_spawn_location_events).
Sprinting Spriggans:  server_battlenpc_spawn_locations 113000-113008.

The Dreamer's Gospel (Spl0u1, Spl0g1, Spl0l1): a Dreamer in each city
(Kikina in Ul'dah, Jihli Aliapoh in Gridania, Motte in Limsa Lominsa) sings
that heroes will gather the Archon eggs. She gives an Archon egg, and
another (a random one) every EGG_WAIT_MINUTES; spriggans in the field
(shuffling, scrambling and scurrying) also drop aspected eggs. Her helper
(Wadard, Bricot, Fhlae) trades an Archon egg plus lightning, earth and
water eggs for the Pristine Egg Cap. One Gospel per adventurer.

The Dreamer's Dilemma (Spl0u2, Spl0g2, Spl0l2): the city's spriggan thief
(Ziggy, Twiggy, Iggy) ran off with the Dreamer's eggs. The fancy eggs
(Archon, colored, painted, darkened) come from Sprinting Spriggans in the
cave the hint spriggan (Figgy, Diggy, Wiggy) names; the thief hides in
another cave. The helper trades each fancy egg plus aspected eggs for a
cap, and the thief trades all four fancy eggs for the Chocobo Egg Cap.
The first cap completes the quest; trading goes on while the event runs.

Our choices, where the client gives no number: one of each egg per recipe
(the client fills the counts from the quest), an egg from the Dreamer every
EGG_WAIT_MINUTES, aspected eggs from one field spriggan kill in
FIELD_EGG_CHANCE, a fancy egg from every Sprinting Spriggan kill, and where
the caves are (the darkened-egg cave of each city: Copperbell Mines, the
Tam-Tara Deepcroft, Mistbeard Cove; the thief's: Nanawa Mines, the Mun-Tuy
Cellars, Cassiopeia Hollow).

]]

HATCHINGTIDE = {
	EVENT				= "hatchingtide",

	-- Eggs. The fancy ones are rare (one of each at a time).
	ARCHON_EGG			= 10012001,
	COLORED_EGG			= 10012002,
	PAINTED_EGG			= 10012003,
	DARKENED_EGG		= 10012004,
	WIND_EGG			= 10012005,
	LIGHTNING_EGG		= 10012006,
	FIRE_EGG			= 10012007,
	EARTH_EGG			= 10012008,
	ICE_EGG				= 10012009,
	WATER_EGG			= 10012010,
	ASTRAL_EGG			= 10012011,
	UMBRAL_EGG			= 10012012,

	-- Caps
	PRISTINE_CAP		= 8012801,
	VIBRANT_CAP			= 8012802,
	BRILLIANT_CAP		= 8012803,
	MIDNIGHT_CAP		= 8012804,
	CHOCOBO_CAP			= 8012805,

	EGG_WAIT_MINUTES	= 10,		-- the Dreamer's next egg ("over 10")
	FIELD_EGG_CHANCE	= 2,		-- one field spriggan kill in this many drops an egg

	-- Battle npc classes
	FIELD_SPRIGGANS		= {[2106210] = true, [2106211] = true, [2106212] = true},	-- shuffling, scrambling, scurrying
	SPRINTING_SPRIGGAN	= 2106213,

	-- The client's hint argument: up to 9 names the darkened-egg cave,
	-- above it the thief's cave.
	HINT_FANCY_CAVE		= 8,
	HINT_THIEF_CAVE		= 100,
};

local H = HATCHINGTIDE;

H.ELEMENT_EGGS = {H.FIRE_EGG, H.ICE_EGG, H.WIND_EGG, H.EARTH_EGG, H.LIGHTNING_EGG, H.WATER_EGG, H.ASTRAL_EGG, H.UMBRAL_EGG};
H.FANCY_EGGS = {H.ARCHON_EGG, H.COLORED_EGG, H.PAINTED_EGG, H.DARKENED_EGG};

-- The helper's caps, in the order of the client's "Trade for which cap?"
-- menu, and the eggs each takes (the client's lines name them).
H.CAPS = {
	{cap = H.PRISTINE_CAP,	eggs = {H.ARCHON_EGG, H.LIGHTNING_EGG, H.EARTH_EGG, H.WATER_EGG}},
	{cap = H.VIBRANT_CAP,	eggs = {H.COLORED_EGG, H.FIRE_EGG, H.WIND_EGG, H.ICE_EGG}},
	{cap = H.BRILLIANT_CAP,	eggs = {H.PAINTED_EGG, H.ASTRAL_EGG, H.FIRE_EGG, H.WIND_EGG, H.LIGHTNING_EGG}},
	{cap = H.MIDNIGHT_CAP,	eggs = {H.DARKENED_EGG, H.UMBRAL_EGG, H.EARTH_EGG, H.WATER_EGG, H.ICE_EGG}},
};
H.GOSPEL_EGGS = H.CAPS[1].eggs;

-- Each city: its two quests and the cast (actor class ids).
H.CITIES = {
	uldah = {
		gospel = 110789, gospelCode = "Spl0u1", dilemma = 110790, dilemmaCode = "Spl0u2",
		dreamer = 1001584, helper = 1001585, hint = 1001586, thief = 1001999,	-- Kikina, Wadard, Figgy, Ziggy
	},
	gridania = {
		gospel = 110794, gospelCode = "Spl0g1", dilemma = 110795, dilemmaCode = "Spl0g2",
		dreamer = 1001588, helper = 1001589, hint = 1001591, thief = 1001998,	-- Jihli Aliapoh, Bricot, Diggy, Twiggy
	},
	limsa = {
		gospel = 110804, gospelCode = "Spl0l1", dilemma = 110805, dilemmaCode = "Spl0l2",
		dreamer = 1001592, helper = 1001593, hint = 1001595, thief = 1001997,	-- Motte, Fhlae, Wiggy, Iggy
	},
};

-- class id -> {city, role}
H.CAST = {};
for _, c in pairs(H.CITIES) do
	H.CAST[c.dreamer] = {city = c, role = "dreamer"};
	H.CAST[c.helper] = {city = c, role = "helper"};
	H.CAST[c.hint] = {city = c, role = "hint"};
	H.CAST[c.thief] = {city = c, role = "thief"};
end

H.GOSPELS = {H.CITIES.uldah.gospel, H.CITIES.gridania.gospel, H.CITIES.limsa.gospel};
H.DILEMMAS = {H.CITIES.uldah.dilemma, H.CITIES.gridania.dilemma, H.CITIES.limsa.dilemma};

local function anyOf(player, ids, test)
	for _, id in ipairs(ids) do
		if (test(player, id)) then
			return true;
		end
	end
	return false;
end

function hatchFinishedGospel(player)
	return anyOf(player, H.GOSPELS, function(p, id) return p:IsQuestCompleted(id); end);
end

function hatchOnDilemma(player)
	return anyOf(player, H.DILEMMAS, function(p, id) return p:HasQuest(id); end);
end

function hatchFinishedDilemma(player)
	return anyOf(player, H.DILEMMAS, function(p, id) return p:IsQuestCompleted(id); end);
end

local function bag(player)
	return player:GetItemPackage(INVENTORY_NORMAL);
end

-- Whether the player holds every egg in `eggs`.
function hatchHasEggs(player, eggs)
	local b = bag(player);
	for _, egg in ipairs(eggs) do
		if (not b:HasItem(egg, 1)) then
			return false;
		end
	end
	return true;
end

function hatchTakeEggs(player, eggs)
	local b = bag(player);
	for _, egg in ipairs(eggs) do
		b:RemoveItem(egg, 1);
	end
end

-- One egg into the bag: `pick` lists the candidates; a rare egg the
-- player already holds is skipped (an aspected egg comes instead).
function hatchGiveEgg(player, pick)
	local b = bag(player);
	local choices = {};
	for _, egg in ipairs(pick) do
		if (not (b:HasItem(egg, 1) and (egg <= H.DARKENED_EGG))) then
			table.insert(choices, egg);
		end
	end
	if (#choices == 0) then
		choices = H.ELEMENT_EGGS;
	end
	local egg = choices[math.random(#choices)];
	b:AddItem(egg, 1, 1);
	return egg;
end

-- The Dreamer's eggs: the time of the last one is kept in a quest counter
-- as minutes, modulo 65536 (45 days, longer than the event).
local function nowMinutes()
	return math.floor(os.time() / 60) % 65536;
end

function hatchStampEgg(quest, counter)
	quest:GetData():SetCounter(counter, nowMinutes());
end

function hatchEggReady(quest, counter)
	local elapsed = (nowMinutes() - quest:GetData():GetCounter(counter)) % 65536;
	return elapsed >= H.EGG_WAIT_MINUTES;
end

-- A spriggan falls. Field spriggans drop aspected eggs for anyone on a
-- Gospel or Dilemma; Sprinting Spriggans drop fancy eggs on the Dilemma.
-- Called by every Hatching-tide quest the player has; `dilemma` says which
-- kind is asking, so a player on both gets one egg, not two.
function hatchOnKill(player, bnpc, dilemma)
	if (not dilemma and hatchOnDilemma(player)) then
		return;	-- the Dilemma's hook drops it
	end
	if (H.FIELD_SPRIGGANS[bnpc]) then
		if (math.random(H.FIELD_EGG_CHANCE) == 1) then
			hatchGiveEgg(player, H.ELEMENT_EGGS);
		end
	elseif (bnpc == H.SPRINTING_SPRIGGAN and dilemma) then
		hatchGiveEgg(player, H.FANCY_EGGS);
	end
end

-- The helper's cap menu (the client's eventBricotExchange): each cap's
-- argument is 1 (the eggs are here), 2 (already given) or 0 (not enough).
-- `given(i)` says whether cap i was already traded. Returns the cap traded
-- (an item id), or nil.
function hatchCapExchange(player, quest, given)
	local args = {};
	for i, c in ipairs(H.CAPS) do
		if (given(i) or bag(player):HasItem(c.cap, 1)) then
			args[i] = 2;
		elseif (hatchHasEggs(player, c.eggs)) then
			args[i] = 1;
		else
			args[i] = 0;
		end
	end
	local pick = callClientFunction(player, "delegateEvent", player, quest, "eventBricotExchange",
		args[1], args[2], args[3], args[4]);
	if (type(pick) ~= "number" or H.CAPS[pick] == nil or args[pick] ~= 1) then
		return nil;
	end
	hatchTakeEggs(player, H.CAPS[pick].eggs);
	bag(player):AddItem(H.CAPS[pick].cap, 1, 1);
	return pick;
end

-- The thief trades all four fancy eggs for the Chocobo Egg Cap. Returns
-- true when it did.
function hatchThiefTalk(player, quest, firstMeeting)
	local b = bag(player);
	if (b:HasItem(H.CHOCOBO_CAP, 1)) then
		callClientFunction(player, "delegateEvent", player, quest, "eventTwiggyResist");
	elseif (hatchHasEggs(player, H.FANCY_EGGS)) then
		callClientFunction(player, "delegateEvent", player, quest, "eventTwiggyExchange");
		hatchTakeEggs(player, H.FANCY_EGGS);
		b:AddItem(H.CHOCOBO_CAP, 1, 1);
		return true;
	elseif (firstMeeting) then
		callClientFunction(player, "delegateEvent", player, quest, "eventTwiggyOffered");
	else
		callClientFunction(player, "delegateEvent", player, quest, "eventTwiggyHint");
	end
	return false;
end

local function hasAnyFancy(player)
	local b = bag(player);
	for _, egg in ipairs(H.FANCY_EGGS) do
		if (b:HasItem(egg, 1)) then
			return true;
		end
	end
	return false;
end
hatchHasAnyFancy = hasAnyFancy;

function hatchHint(player, quest)
	local n = (math.random(2) == 1) and H.HINT_FANCY_CAVE or H.HINT_THIEF_CAVE;
	callClientFunction(player, "delegateEvent", player, quest, "eventDiggyHint", n);
end

-- A Hatching-tide NPC that no quest of the player's answers for
-- (unique/<zone>/PopulaceStandard/hatch_*.lua).
function hatchingtideTalk(player, npc)
	local cast = H.CAST[npc:GetActorClassId()];
	if (cast == nil or not IsSeasonalEventActive(H.EVENT)) then
		player:EndEvent();
		return;
	end
	local c, role = cast.city, cast.role;
	local gospel = GetStaticActor(c.gospelCode);
	local dilemma = GetStaticActor(c.dilemmaCode);
	local doneDilemma = hatchFinishedDilemma(player);

	if (role == "dreamer") then
		if (hatchFinishedGospel(player)) then
			callClientFunction(player, "delegateEvent", player, dilemma, "eventJihliDefault");
		else
			callClientFunction(player, "delegateEvent", player, gospel, "beforeGirl");
		end
	elseif (role == "helper") then
		if (doneDilemma and hasAnyFancy(player)) then
			hatchCapExchange(player, dilemma, function() return false; end);
		elseif (doneDilemma) then
			callClientFunction(player, "delegateEvent", player, dilemma, "eventBricotHint");
		elseif (hatchFinishedGospel(player)) then
			if (hatchHasEggs(player, H.GOSPEL_EGGS)) then
				callClientFunction(player, "delegateEvent", player, gospel, "isCapMes");
			else
				callClientFunction(player, "delegateEvent", player, gospel, "afterBoy");
			end
		else
			callClientFunction(player, "delegateEvent", player, gospel, "beforeBoy");
		end
	elseif (role == "hint") then
		if (doneDilemma) then
			hatchHint(player, dilemma);
		elseif (hatchFinishedGospel(player)) then
			callClientFunction(player, "delegateEvent", player, dilemma, "eventDiggyDefault");
		else
			callClientFunction(player, "delegateEvent", player, gospel, "beforeSp2");
		end
	elseif (role == "thief") then
		if (doneDilemma) then
			hatchThiefTalk(player, dilemma, false);
		else
			callClientFunction(player, "delegateEvent", player, dilemma, "eventTwiggyDefault");
		end
	end
	player:EndEvent();
end
