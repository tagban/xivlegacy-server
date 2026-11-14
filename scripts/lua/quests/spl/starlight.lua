--[[

Starlight Celebration: the numbers and ids Spl0i3 and Spl0i4 share, kept
in one place so they are easy to change.

When the event runs:  settings/events.toml ([starlight]), or `!event`.
Where its NPCs stand: common/sql/data/server_spawn_locations.sql,
                      ids 30900-30908 (tagged in server_spawn_location_events).

Spl0i3 "Winter Is Not Coming" (Dec 16-31 in 1.0): a Black Rabbit Traders
rep takes ICE_SHARDS_NEEDED Ice Shards and hands over SNOWBALLS ensorcelled
snowballs; the player throws them at Father Frost in Hyrstmill (Snowball
emote) and Waldomar gives the reindeer outfit.

Spl0i4 "Gone with the Snow" (Dec 31-Jan 16): Father Frost is gone; the
player searches Hyrstmill, finds the ice elemental at the hamlet's edge and
Waldomar gives a Dragon Kabuto. Each city rep then gives that city's kabuto.

]]

STARLIGHT = {
	EVENT				= "starlight",

	-- Spl0i3. The client's lines say "30" themselves: keep the two in step.
	ICE_SHARD			= 1000004,	-- crystals live in INVENTORY_CURRENCY
	ICE_SHARDS_NEEDED	= 30,
	SNOWBALL			= 11000217,	-- Ensorcelled Snowball (key item)
	SNOWBALLS			= 5,		-- throws at Father Frost
	SPL0I3_REWARDS		= {8012502, 8032102},	-- Reindeer Antlers, Reindeer Suit
	SPL0I3_EXP			= 0,

	-- Spl0i4
	HEART_OF_WINTER		= 11000218,	-- key item, from the elemental
	SPL0I4_REWARD		= 8012604,	-- Dragon Kabuto, from Waldomar
	SPL0I4_EXP			= 0,

	-- NPCs (actor class ids)
	NINIPU				= 1001824,	-- Limsa Lominsa
	HASTRIDIE			= 1001825,	-- Gridania
	WYSSKOEN			= 1001826,	-- Ul'dah
	WALDOMAR			= 1001827,	-- Hyrstmill
	FATHER_FROST		= 1200265,	-- Hyrstmill (ObjectBigSnowMan)
	SPOT_A				= 1090990,	-- Spl0i4 search spots (push circles)
	SPOT_B				= 1090991,
	SPOT_C				= 1090992,
	HAMLET_GATE			= 1090993,	-- Spl0i4 elemental cutscene trigger
};

-- Each rep: Spl0i3's city argument (0 Limsa, 1 Gridania, 2 Ul'dah), Spl0i4's
-- (1 Limsa, 2 Gridania, 3 Ul'dah), Spl0i3's offer event, and the kabuto the
-- rep gives once Spl0i4 is done.
STARLIGHT.REPS = {
	[STARLIGHT.NINIPU]		= {spl0i3 = 0, spl0i4 = 1, offer = "processEventRimStart", kabuto = 8012607},	-- Black
	[STARLIGHT.HASTRIDIE]	= {spl0i3 = 1, spl0i4 = 2, offer = "processEventGriStart", kabuto = 8012605},	-- Crimson
	[STARLIGHT.WYSSKOEN]	= {spl0i3 = 2, spl0i4 = 3, offer = "processEventUldStart", kabuto = 8012606},	-- Golden
};

SPL0I3_ID = 110801;
SPL0I4_ID = 110802;

-- What a rep says to a player no quest of theirs answers for: the Spl0i4
-- hint, the kabuto, or Spl0i3's thanks.
function starlightRepTalk(player, npc)
	local rep = STARLIGHT.REPS[npc:GetActorClassId()];
	if (rep == nil) then
		player:EndEvent();
		return;
	end
	local spl0i3 = GetStaticActor("Spl0i3");
	local spl0i4 = GetStaticActor("Spl0i4");
	if (player:IsQuestCompleted(SPL0I4_ID)) then
		local bag = player:GetItemPackage(INVENTORY_NORMAL);
		if (not bag:HasItem(rep.kabuto, 1)) then
			callClientFunction(player, "delegateEvent", player, spl0i4, "processEventClearAfterItem", rep.spl0i4);
			bag:AddItem(rep.kabuto, 1, 1);
		else
			callClientFunction(player, "delegateEvent", player, spl0i4, "processEventClearAfterItemAfter", rep.spl0i4);
		end
	elseif (IsSeasonalQuestOpen(SPL0I4_ID) and not player:HasQuest(SPL0I4_ID)) then
		local helped = player:IsQuestCompleted(SPL0I3_ID) and 1 or 0;
		callClientFunction(player, "delegateEvent", player, spl0i4, "processEventHin", rep.spl0i4, helped);
	elseif (player:HasQuest(SPL0I4_ID)) then
		callClientFunction(player, "delegateEvent", player, spl0i4, "processEventHin", rep.spl0i4, 1);
	else
		callClientFunction(player, "delegateEvent", player, spl0i3, "processEventXmasAfterdefo", rep.spl0i3);
	end
	player:EndEvent();
end
