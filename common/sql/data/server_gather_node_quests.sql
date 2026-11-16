-- server_gather_node_quests: quest-only gathering points (our own, not retail data). Reloaded whole when this file changes.
-- A gathering point (server_gather_node_spawns.id) listed here is shown to, and can be worked by, only a player
-- holding one of its quests at one of its sequences. Points not listed are for everyone.
-- 9140: Fsh200 (110500) SEQ_010, the pixie remora on the Lower La Noscea shore.
SET SESSION sql_mode = 'ANSI_QUOTES,PIPES_AS_CONCAT,STRICT_ALL_TABLES,NO_AUTO_VALUE_ON_ZERO,NO_ENGINE_SUBSTITUTION';
DELETE FROM `server_gather_node_quests`;
INSERT INTO `server_gather_node_quests` (`spawnId`, `questId`, `sequence`) VALUES
(9120, 110481, 14),
(9121, 110481, 14),
(9122, 110482, 34),
(9140, 110500, 10);
