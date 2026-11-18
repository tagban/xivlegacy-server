-- server_battlenpc_pool_mods: game data, 8 rows. Reloaded whole when this file changes.
SET SESSION sql_mode = 'ANSI_QUOTES,PIPES_AS_CONCAT,STRICT_ALL_TABLES,NO_AUTO_VALUE_ON_ZERO,NO_ENGINE_SUBSTITUTION';
DELETE FROM `server_battlenpc_pool_mods`;
INSERT INTO `server_battlenpc_pool_mods` (`poolId`, `modId`, `modVal`, `isMobMod`) VALUES
(2, 2, 3, 1),
(2, 3, 3, 1),
(2, 24, 0, 1),
(3, 24, 0, 1),
(3, 49, 1, 0),
(4, 24, 0, 1),
(4, 49, 1, 0),
(30114, 15, 1, 1);
