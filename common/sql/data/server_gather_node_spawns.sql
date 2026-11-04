-- server_gather_node_spawns: game data, 2 rows. Reloaded whole when this file changes.
SET SESSION sql_mode = 'ANSI_QUOTES,PIPES_AS_CONCAT,STRICT_ALL_TABLES,NO_AUTO_VALUE_ON_ZERO,NO_ENGINE_SUBSTITUTION';
DELETE FROM `server_gather_node_spawns`;
INSERT INTO `server_gather_node_spawns` (`id`, `actorClassId`, `uniqueId`, `zoneId`, `privateAreaName`, `privateAreaLevel`, `positionX`, `positionY`, `positionZ`, `rotation`, `harvestNodeId`, `harvestType`) VALUES
(1, 4100001, 'mining_outcrop_central_thanalan_1', 180, '', 0, -45.12, 12.8, 31.04, 0.0, 1001, 22002),
(2, 4100001, 'mining_outcrop_central_thanalan_2', 180, '', 0, -12.5, 14.4, 64.22, 1.57, 1002, 22002);
