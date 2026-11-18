--[[

Moonfire Faire: the numbers and ids The Heat Is On (Spl0i1, 2011) and
Bombard Backlash (Spl102, 2012) share, kept in one place so they are easy
to change.

When the event runs:  settings/events.toml ([moonfire]), or `!moonfire`.
Where its NPCs stand: common/sql/data/server_spawn_locations.sql,
                      ids 31270-31298 (tagged in server_spawn_location_events).

The Heat Is On: a faire chaperone in each city (Xheh Jakkya in Limsa
Lominsa, Judye in Gridania, Miette in Ul'dah) signs the player up with
the Cascadiers and hands over the Lunar summer suit. Cascadier cadets in
the field (Aleport, Quarrymill, the Silver Bazaar, Camp Dragonhead) have a
Bombard nearby: dance at it (/dance) and it bursts; the cadet then gives
its ash, colored by region. The chaperone trades ash for sparklers and the
four large fireworks, and a lost Lunar suit for one pinch of ash.

Bombard Backlash: a year on, the Bombards rose from their ashes. The same
chaperones, now in yukata, send the player to a bomb site by the first
camp outside the city; the Firedancers (Hildibrand in Limsa Lominsa,
Radolf in Gridania, Galsha Zasha in Ul'dah) teach the fire dance. Dancing
at a Bombard bursts it (a Bombard King takes three dances); the site's
cadet gives Bombard Ash, which the chaperone trades for yukata, drawers,
clogs and Bombard Blooms.

Our choices, where the client gives none: which region gives which ash
color (the 2011 faire's own map is lost), the field spots, the ash a
Bombard leaves (ASH_2011, ASH_PER_BOMBARD, ASH_PER_KING), the colored
summer suits ("special variants" the client keeps for outstanding service)
with the large firework of that color and the Solar suit with Azeyma's
Candle, Bombard Backlash following The Heat Is On, and each
quest finishing at its top reward (Azeyma's Candle; the 50-ash yukata and
drawers), so that the dancing goes on until then.

]]

MOONFIRE = {
	EVENT				= "moonfire",

	SPL0I1_ID			= 110799,
	SPL102_ID			= 110860,

	-- 2011 ash and fireworks
	RED_ASH				= 10012014,
	BLUE_ASH			= 10012015,
	GREEN_ASH			= 10012016,
	BLACK_ASH			= 10012017,
	AZEYMAS_CANDLE		= 10012021,

	ASH_2011			= 3,		-- ash per burst Bombard

	-- 2012 ash
	BOMBARD_ASH			= 10011253,
	ASH_PER_BOMBARD		= 3,
	ASH_PER_KING		= 10,
	KING_DANCES			= 3,

	DANCE_EMOTE			= "emoteDefault1",	-- the /dance emote event (emote 111)
};

local M = MOONFIRE;

-- The 2011 rewards, in the client's reward list order (Ask/RewardSelectWidget),
-- and the ash each costs (the client's own confirmation lines).
M.FIREWORKS = {
	{item = 3020604, cost = {[M.RED_ASH] = 1}},		-- Lominsan Sparkler
	{item = 3020605, cost = {[M.GREEN_ASH] = 1}},	-- Gridanian Sparkler
	{item = 3020606, cost = {[M.BLUE_ASH] = 1}},	-- Ul'dahn Sparkler
	{item = 10012018, cost = {[M.RED_ASH] = 3}, suit = "red"},	-- Red Lion
	{item = 10012019, cost = {[M.BLUE_ASH] = 3}, suit = "blue"},	-- Blue Spinner
	{item = 10012020, cost = {[M.GREEN_ASH] = 3}, suit = "green"},	-- Green Comet
	{item = 10012021, cost = {[M.RED_ASH] = 3, [M.BLUE_ASH] = 3, [M.GREEN_ASH] = 3, [M.BLACK_ASH] = 3}, suit = "solar"},	-- Azeyma's Candle
};

-- Summer suits: {male top, male trunks, female halter, female tanga}.
M.SUITS = {
	lunar	= {8032405, 8051305, 8032410, 8051310},
	red		= {8032401, 8051301, 8032406, 8051306},
	green	= {8032402, 8051302, 8032407, 8051307},
	blue	= {8032403, 8051303, 8032408, 8051308},
	solar	= {8032404, 8051304, 8032409, 8051309},
};
-- The uniform menu: the Lunar suit for one pinch of the ash picked
-- (red, blue, green, in the client's order).
M.UNIFORM_ASH = {M.RED_ASH, M.BLUE_ASH, M.GREEN_ASH};

-- The 2012 rewards, in the client's list order: {male, female, ash}.
M.GEAR = {
	{8032834, 8032837, 1},	-- yukata (blue / red)
	{8032835, 8032838, 30},	-- yukata (green / blue)
	{8032836, 8032839, 50},	-- yukata (grey / black)
	{8051521, 8051524, 1},	-- drawers / knickers (black)
	{8051522, 8051525, 30},	-- (white)
	{8051523, 8051526, 50},	-- (gold)
	{8081921, 8081922, 5},	-- clogs
	{3020613, 3020613, 1},	-- Bombard Bloom (any number)
};
-- The list returns its pick (1-8) plus this (client-tested: Bombard Bloom 18).
M.GEAR_PICK_BASE = 10;
M.STARTER_GEAR = {1, 4};	-- the yukata and drawers every recruit gets
M.TOP_GEAR = {3, 6};		-- both 50-ash pieces finish Bombard Backlash
M.BLOOM = 8;

-- NPCs (actor class ids). city: the client's argument (0 Limsa Lominsa,
-- 1 Gridania, 2 Ul'dah). Each year has its own chaperones (2012's wear
-- yukata).
M.CHAPERONES_2011 = {
	[0] = 1001669,	-- Faire Chaperone Xheh Jakkya
	[1] = 1001671,	-- Faire Chaperone Judye
	[2] = 1001670,	-- Faire Chaperone Miette
};
M.CHAPERONES_2012 = {
	[0] = 1002081,
	[1] = 1002082,
	[2] = 1002083,
};
M.DANCERS = {	-- the Firedancers (Spl102)
	[0] = 1002097,	-- Firedancer Hildibrand
	[1] = 1002098,	-- Firedancer Radolf
	[2] = 1002099,	-- Firedancer Galsha Zasha
};
-- The field. Every site is in a zone of its own, which is how a Bombard
-- (one class for all the sites of a year) is told apart.
-- 2011: a Cascadier cadet and a Bombard at each, and the ash color
-- (variant: the cadet's line, 0 Limsa Lominsa's, 1 the others').
M.BOMBARD_2011 = 2201606;
M.SITES_2011 = {
	{zone = 129, officer = 1001653, ash = M.RED_ASH, variant = 0},	-- Aleport: Cascadier Cadet Kheni Molkoh
	{zone = 154, officer = 1001666, ash = M.GREEN_ASH, variant = 1},	-- Quarrymill: Cascadier Cadet Sterrklin
	{zone = 172, officer = 1001662, ash = M.BLUE_ASH, variant = 1},	-- the Silver Bazaar: Cascadier Cadet Pfymberk
	{zone = 143, officer = 1001657, ash = M.BLACK_ASH, variant = 1},	-- Camp Dragonhead: Cascadier Cadet Lhei Mhakaracca
};
-- 2012: a bomb site by the first camp outside each city, with a Bombard
-- and a Bombard King.
M.BOMBARD_2012 = 2201611;
M.KING_2012 = 2201612;
M.SITES_2012 = {
	[0] = {zone = 128, officer = 1002080, variant = 0},	-- Camp Bearded Rock: Cascadier Cadet Lhei Mhakaracca
	[1] = {zone = 150, officer = 1002079, variant = 1},	-- Camp Bentbranch: Cascadier Cadet Kheni Molkoh
	[2] = {zone = 170, officer = 1002078, variant = 1},	-- Camp Black Brush: Cascadier Cadet L'mogavha
};

-- What DoEmote replays at a Bombard (commands/EmoteStandardCommand.lua):
-- /dance (emote 111, the Bombards' emoteDefault1) and, for the 2012
-- Bombards, the fire dance (emote 156, emoteDefault2).
M.DANCE_DO_EMOTE = 11;
M.DANCE_MOTION = 21101;
M.FIRE_DANCE_EVENT = "emoteDefault2";
M.FIRE_DANCE_DO_EMOTE = 55;
M.FIRE_DANCE_MOTION = 21445;

-- The 2011 reward list returns its pick (1-7) plus this (client-tested:
-- Red Lion 104).
M.REWARD_PICK_BASE = 100;
-- The 2011 uniform menu returns its ash pick (1-3) plus this (client-tested:
-- red 111, blue 112).
M.UNIFORM_PICK_BASE = 110;

-- class id -> {role, city, year}
M.CAST = {};
for city, c in pairs(M.CHAPERONES_2011) do M.CAST[c] = {role = "chaperone", city = city, year = 2011}; end
for city, c in pairs(M.CHAPERONES_2012) do M.CAST[c] = {role = "chaperone", city = city, year = 2012}; end
for city, c in pairs(M.DANCERS) do M.CAST[c] = {role = "dancer", city = city, year = 2012}; end

local function bag(player)
	return player:GetItemPackage(INVENTORY_NORMAL);
end
moonfireBag = bag;

function moonfireHasAll(player, cost)
	for item, n in pairs(cost) do
		if (not bag(player):HasItem(item, n)) then
			return false;
		end
	end
	return true;
end

function moonfireTake(player, cost)
	for item, n in pairs(cost) do
		bag(player):RemoveItem(item, n);
	end
end

-- Male tribes (playerWork.tribe): Hyur Midlander and Highlander, both
-- Elezen, both Lalafell, both Roegadyn. Miqo'te are female.
local MALE_TRIBES = {[1] = true, [3] = true, [4] = true, [6] = true, [8] = true, [10] = true, [14] = true, [15] = true};

function moonfireIsMale(player)
	return MALE_TRIBES[player.playerWork.tribe] == true;
end

-- The summer suit for the player's sex: {top, bottom}.
function moonfireSuit(player, name)
	local s = M.SUITS[name];
	if (moonfireIsMale(player)) then
		return {s[1], s[2]};
	end
	return {s[3], s[4]};
end

function moonfireGive(player, items)
	for _, item in ipairs(items) do
		bag(player):AddItem(item, 1, 1);
	end
end

function moonfireHasAny(player, items)
	for _, item in ipairs(items) do
		if (bag(player):HasItem(item, 1)) then
			return true;
		end
	end
	return false;
end

-- The 2011 site in the player's zone: its index and entry, or nil.
function moonfireSite2011(player)
	local zone = player:GetZoneID();
	for i, s in ipairs(M.SITES_2011) do
		if (s.zone == zone) then return i, s; end
	end
	return nil;
end

-- The 2012 site in the player's zone: its city and entry, or nil.
function moonfireSite2012(player)
	local zone = player:GetZoneID();
	for city, s in pairs(M.SITES_2012) do
		if (s.zone == zone) then return city, s; end
	end
	return nil;
end

-- A Moonfire NPC that no quest of the player's answers for.
function moonfireTalk(player, npc)
	local cast = M.CAST[npc:GetActorClassId()];
	if (cast == nil or not IsSeasonalEventActive(M.EVENT)) then
		player:EndEvent();
		return;
	end
	if (cast.role == "dancer") then
		local names = {[0] = "processEventBdanceBeforeOfferSea", [1] = "processEventBdanceBeforeOfferFst", [2] = "processEventBdanceBeforeOfferWil"};
		callClientFunction(player, "delegateEvent", player, GetStaticActor("Spl102"), names[cast.city]);
	end
	player:EndEvent();
end
