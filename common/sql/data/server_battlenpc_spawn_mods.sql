-- server_battlenpc_spawn_mods: game data, 3 rows. Reloaded whole when this file changes.
SET SESSION sql_mode = 'ANSI_QUOTES,PIPES_AS_CONCAT,STRICT_ALL_TABLES,NO_AUTO_VALUE_ON_ZERO,NO_ENGINE_SUBSTITUTION';
DELETE FROM `server_battlenpc_spawn_mods`;
INSERT INTO `server_battlenpc_spawn_mods` (`bnpcId`, `modId`, `modVal`, `isMobMod`) VALUES
(3, 25, 30, 1),
(4, 25, 35, 1),
(5, 25, 40, 1);
