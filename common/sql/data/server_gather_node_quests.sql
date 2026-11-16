-- server_gather_node_quests: quest-only gathering points (our own, not retail data). Reloaded whole when this file changes.
-- A gathering point (server_gather_node_spawns.id) listed here is shown to, and can be worked by, only a player
-- holding one of its quests at one of its sequences. Points not listed are for everyone.
SET SESSION sql_mode = 'ANSI_QUOTES,PIPES_AS_CONCAT,STRICT_ALL_TABLES,NO_AUTO_VALUE_ON_ZERO,NO_ENGINE_SUBSTITUTION';
DELETE FROM `server_gather_node_quests`;
INSERT INTO `server_gather_node_quests` (`spawnId`, `questId`, `sequence`) VALUES
(9180, 110460, 15),
(9181, 110460, 15),
(9182, 110460, 15);
