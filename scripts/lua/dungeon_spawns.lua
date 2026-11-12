-- Each dungeon zone's battle npc ids (server_battlenpc_spawn_locations),
-- spawned into every copy: a list of {first, last} ranges per zone.
-- Seed 130_dungeon_monsters.sql made the first range of each zone (positions
-- from Caladius's placement sheets); bosses follow in ranges of their own.

DUNGEON_SPAWNS = {
	[159] = {{3319, 3456}, {3457, 3459}},	-- Toto-Rak; Antares, Sargas, Shaula
	[231] = {{3179, 3318}, {2000, 2101}},	-- bosses, then filler packs and adds
	[245] = {{3001, 3091}},
	[246] = {{3092, 3178}},
}
