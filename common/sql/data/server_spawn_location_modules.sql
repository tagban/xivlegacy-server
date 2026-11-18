-- server_spawn_location_modules: spawns that belong to an optional module (modules/README.md) and appear only while it is enabled. Reloaded whole when this file changes.
--   31901-31903 the Monster Points vendors Nibbles (Ul'dah), Mogsley (Gridania), Gobbie (Limsa): monstermode.
SET SESSION sql_mode = 'ANSI_QUOTES,PIPES_AS_CONCAT,STRICT_ALL_TABLES,NO_AUTO_VALUE_ON_ZERO,NO_ENGINE_SUBSTITUTION';
DELETE FROM `server_spawn_location_modules`;
INSERT INTO `server_spawn_location_modules` (`spawnId`, `module`) VALUES
(31901, 'monstermode'),
(31902, 'monstermode'),
(31903, 'monstermode');
