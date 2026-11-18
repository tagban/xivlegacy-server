-- server_spawn_location_events: spawns that belong to a seasonal event (settings/events.toml). Reloaded whole when this file changes.
-- An event's spawns go to players only while the event runs (its date windows, or a GM's `!event`); a spawn not listed always goes.
-- starlight: the Starlight Celebration (Spl0i3 Winter Is Not Coming, Spl0i4 Gone with the Snow):
--   30900-30902 the Black Rabbit Traders reps Ninipu (Limsa), Hastridie (Gridania), Wysskoen (Ul'dah);
--   30903 Waldomar and 30904 Father Frost in Hyrstmill; 30905-30908 Spl0i4's search spots and hamlet-gate trigger.
--   30930-30940 Starlight posters (MapObjOnlyShowHide 5900006 bound to the city layouts, server_eventnpc_mapobj): Ul'dah 30930-30933, Limsa 30934-30937, Gridania 30938-30940.
-- allsaints: All Saints' Wake (Spl0i2 Impish Impositions):
--   30910-30912 the Adventurers' Guild runners Ursielle (Limsa), Mudede (Gridania), Yvane (Ul'dah);
--   30913-30921 the disguised trickster imps, three per city (night only, see settings/events.toml).
-- hatchingtide: Hatching-tide (Spl0u1/g1/l1 The Dreamer's Gospel, Spl0u2/g2/l2 The Dreamer's Dilemma):
--   31250-31258 the Dreamers, their helpers and hint spriggans (Ul'dah 31250-31252, Gridania 31253-31255, Limsa 31256-31258);
--   31259-31261 the spriggan thieves Ziggy (Nanawa Mines), Twiggy (Mun-Tuy Cellars), Iggy (Cassiopeia Hollow).
SET SESSION sql_mode = 'ANSI_QUOTES,PIPES_AS_CONCAT,STRICT_ALL_TABLES,NO_AUTO_VALUE_ON_ZERO,NO_ENGINE_SUBSTITUTION';
DELETE FROM `server_spawn_location_events`;
INSERT INTO `server_spawn_location_events` (`spawnId`, `eventName`) VALUES
(30900, 'starlight'),
(30901, 'starlight'),
(30902, 'starlight'),
(30903, 'starlight'),
(30904, 'starlight'),
(30905, 'starlight'),
(30906, 'starlight'),
(30907, 'starlight'),
(30908, 'starlight'),
(30910, 'allsaints'),
(30911, 'allsaints'),
(30912, 'allsaints'),
(30913, 'allsaints'),
(30914, 'allsaints'),
(30915, 'allsaints'),
(30916, 'allsaints'),
(30917, 'allsaints'),
(30918, 'allsaints'),
(30919, 'allsaints'),
(30920, 'allsaints'),
(30921, 'allsaints'),
(30930, 'starlight'),
(30931, 'starlight'),
(30932, 'starlight'),
(30933, 'starlight'),
(30934, 'starlight'),
(30935, 'starlight'),
(30936, 'starlight'),
(30937, 'starlight'),
(30938, 'starlight'),
(30939, 'starlight'),
(30940, 'starlight'),
(31250, 'hatchingtide'),
(31251, 'hatchingtide'),
(31252, 'hatchingtide'),
(31253, 'hatchingtide'),
(31254, 'hatchingtide'),
(31255, 'hatchingtide'),
(31256, 'hatchingtide'),
(31257, 'hatchingtide'),
(31258, 'hatchingtide'),
(31259, 'hatchingtide'),
(31260, 'hatchingtide'),
(31261, 'hatchingtide');
