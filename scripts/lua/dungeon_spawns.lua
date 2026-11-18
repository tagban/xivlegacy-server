-- Each dungeon zone's battle npc ids (server_battlenpc_spawn_locations),
-- spawned into every copy: a list of {first, last} ranges per zone.
-- Seed 130_dungeon_monsters.sql made the first range of each zone (positions
-- from Caladius's placement sheets); bosses follow in ranges of their own.

DUNGEON_SPAWNS = {
	[159] = {{3319, 3456}, {3457, 3459}, {2800, 2806}},	-- Toto-Rak; Antares, Sargas, Shaula; chamber adds
	[231] = {{3179, 3318}, {2000, 2101}, {2102, 2242}},	-- bosses, then filler packs and adds, then fill-in packs
	[245] = {{3001, 3091}, {2300, 2390}, {2391, 2521}},	-- bosses, then filler packs and adds, then fill-in packs
	[246] = {{3092, 3178}, {2600, 2716}, {2717, 2799}, {2900, 2999}},	-- bosses, then filler packs and adds, then fill-in packs
}
