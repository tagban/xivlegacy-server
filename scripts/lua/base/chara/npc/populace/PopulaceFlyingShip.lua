--[[

PopulaceFlyingShip Script: Highwind Skyways, the airship counters (#464)

Functions (the client's PopulaceFlyingShip class, text sheet 7620):

eventIn(player, hasTicket, nil, travelPrice) - The departures counter: welcome,
    "Book passage / Learn about services / Nothing", then the destination list
    (Limsa Lominsa, Gridania, Ul'dah; the client greys out the counter's own
    city by its class id) and a confirm naming the fare. Returns the
    destination picked (1 Limsa Lominsa, 2 Gridania, 3 Ul'dah) or nil.
    hasTicket: true = the player holds an unused ticket (no fare is named),
    false = normal, nil = the player can't pay the fare (says so and ends).
eventOut(player, isAborting) - "Leave the landing area?" (30010 adds the
    no-refund warning). Returns true to leave.
eventNG(player) - The arrivals counter: this is the arrivals gate, book at
    the opposite counter.

Which counter is which (the client script greys out a city only for
1500003, 1500055 and 1500208, so those three sell tickets):

    city         departures (eventIn)        arrivals (eventNG)
    Limsa        Faezbroes   1500003         Wineburg 1500207
    Gridania     Lionnellais 1500055         Hida     1500056
    Ul'dah       Stangyth    1500208         Lunnie   1500209

What this server does, and what it leaves out:

* In 1.23b a ticket (key item 2001008, Airship Ticket) sent you on to the
  landing area to board, and eventOut let you leave the landing area without
  flying (the ticket stayed valid). The landing areas and the flight are not
  built here, so buying a ticket flies you at once: the fare is taken and you
  arrive beside the destination's arrivals counter. eventOut is not used.
* A held Airship Ticket is honored: eventIn is told so, no fare is taken,
  and the ticket is used up.
* The fare is not in the client's data (the server hands it to eventIn).
  AIRSHIP_FARE below is this server's choice, not a known 1.0 figure.
* Arriving does not attune the city's aetheryte: attunement comes from
  touching the crystal, and each landing is a short walk from it.
* The quest-reward passes (Airship Pass GRD-LMS 11000208, ULD-LMS 11000209)
  are not honored: eventIn names one fare for every destination, and no
  script puts a pass in a player's key items yet.

Limsa's landing (atop the Mizzenmast) has no zone on this server, so Faezbroes
and Wineburg stand at the foot of Zanthael's lift in zone 133, where Com0l6
already puts the landing's people.

--]]

require ("global")

AIRSHIP_TICKET = 2001008;
AIRSHIP_FARE = 120;
GIL = 1000001;

-- Departures counters: the city they stand in (1 Limsa, 2 Gridania, 3 Ul'dah).
airshipDepartures = {
	[1500003] = 1,	-- Faezbroes
	[1500055] = 2,	-- Lionnellais
	[1500208] = 3,	-- Stangyth
};

-- Where a flight sets you down: zone, x, y, z, rotation (on the floor
-- beside each city's arrivals counter).
airshipLandings = {
	[1] = {133, -442.0, 21.0, 179.0, 1.57},		-- Limsa Lominsa, Zanthael's lift
	[2] = {155, 60.0, -7.0, -1206.0, 0.0},		-- Gridania, by Hida
	[3] = {209, -114.0, 271.2, 160.0, -1.57},	-- Ul'dah, by Lunnie
};

function init(npc)
	return false, false, 0, 0;
end

function onEventStarted(player, npc, triggerName)
	local here = airshipDepartures[npc:GetActorClassId()];

	-- Arrivals counters (Wineburg, Hida, Lunnie) only point you across.
	if (here == nil) then
		callClientFunction(player, "eventNG", player);
		player:EndEvent();
		return;
	end

	local keyItems = player:GetItemPackage(INVENTORY_KEYITEMS);
	local hasTicket = keyItems:HasItem(AIRSHIP_TICKET);
	local ticketArg = false;
	if (hasTicket) then
		ticketArg = true;
	elseif (player:GetCurrentGil() < AIRSHIP_FARE) then
		ticketArg = nil;	-- the client says the fare can't be paid and ends
	end

	local destination = callClientFunction(player, "eventIn", player, ticketArg, nil, AIRSHIP_FARE);
	local landing = airshipLandings[destination];

	if (ticketArg == nil or landing == nil or destination == here) then
		player:EndEvent();
		return;
	end

	if (hasTicket) then
		keyItems:RemoveItem(AIRSHIP_TICKET, 1);
	else
		player:GetItemPackage(INVENTORY_CURRENCY):RemoveItem(GIL, AIRSHIP_FARE);
	end

	-- Close the talk first, then move (the warp tears the event down).
	player:EndEvent();
	GetWorldManager():DoZoneChange(player, landing[1], nil, 0, SPAWN_LOADING1,
		landing[2], landing[3], landing[4], landing[5]);
end
