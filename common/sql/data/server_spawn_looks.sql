-- server_spawn_looks: spawns that wear another actor class's model and gear. Reloaded whole when this file changes.
-- The Monster Points vendors (scripts/lua/monsterpoints.lua) are shop NPCs in monster bodies:
--   31901 Nibbles Coinwhisker (Ul'dah): the Qiqirn look of townsperson 1000217.
--   31902 Mogsley Pompomtrade (Gridania): the Moogle look 1000327.
--   31903 Gobbie Grubtrader (Limsa Lominsa): the Goblin look of townsperson 1001573.
SET SESSION sql_mode = 'ANSI_QUOTES,PIPES_AS_CONCAT,STRICT_ALL_TABLES,NO_AUTO_VALUE_ON_ZERO,NO_ENGINE_SUBSTITUTION';
DELETE FROM `server_spawn_looks`;
INSERT INTO `server_spawn_looks` (`spawnId`, `appearanceClassId`) VALUES
(31901, 1000217),
(31902, 1000327),
(31903, 1001573);
