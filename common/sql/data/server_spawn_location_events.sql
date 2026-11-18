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
-- moonfire: the Moonfire Faire (Spl0i1 The Heat Is On, Spl102 Bombard Backlash):
--   31270-31272 the 2011 Faire Chaperones Xheh Jakkya (Limsa), Judye (Gridania), Miette (Ul'dah); 31273-31275 the same in yukata (2012);
--   31276-31278 the Firedancers Hildibrand (Limsa), Radolf (Gridania), Galsha Zasha (Ul'dah);
--   31280-31287 the 2011 field sites, a Cascadier cadet and a Bombard each: Aleport, Quarrymill, the Silver Bazaar, Camp Dragonhead;
--   31290-31298 the 2012 bomb sites, a cadet, a Bombard and a Bombard King each: Camp Bearded Rock, Camp Bentbranch, Camp Black Brush.
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
(31261, 'hatchingtide'),
(31270, 'moonfire'),
(31271, 'moonfire'),
(31272, 'moonfire'),
(31273, 'moonfire'),
(31274, 'moonfire'),
(31275, 'moonfire'),
(31276, 'moonfire'),
(31277, 'moonfire'),
(31278, 'moonfire'),
(31280, 'moonfire'),
(31281, 'moonfire'),
(31282, 'moonfire'),
(31283, 'moonfire'),
(31284, 'moonfire'),
(31285, 'moonfire'),
(31286, 'moonfire'),
(31287, 'moonfire'),
(31290, 'moonfire'),
(31291, 'moonfire'),
(31292, 'moonfire'),
(31293, 'moonfire'),
(31294, 'moonfire'),
(31295, 'moonfire'),
(31296, 'moonfire'),
(31297, 'moonfire'),
(31298, 'moonfire');
