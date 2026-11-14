-- server_spawn_location_events: spawns that belong to a seasonal event (settings/events.toml). Reloaded whole when this file changes.
-- An event's spawns go to players only while the event runs (its date windows, or a GM's `!event`); a spawn not listed always goes.
-- starlight: the Starlight Celebration (Spl0i3 Winter Is Not Coming, Spl0i4 Gone with the Snow):
--   30900-30902 the Black Rabbit Traders reps Ninipu (Limsa), Hastridie (Gridania), Wysskoen (Ul'dah);
--   30903 Waldomar and 30904 Father Frost in Hyrstmill; 30905-30908 Spl0i4's search spots and hamlet-gate trigger.
-- allsaints: All Saints' Wake (Spl0i2 Impish Impositions):
--   30910-30912 the Adventurers' Guild runners Ursielle (Limsa), Mudede (Gridania), Yvane (Ul'dah);
--   30913-30921 the disguised trickster imps, three per city (night only, see settings/events.toml).
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
(30921, 'allsaints');
