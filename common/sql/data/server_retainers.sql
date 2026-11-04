-- server_retainers: game data, 3 rows. Reloaded whole when this file changes.
SET SESSION sql_mode = 'ANSI_QUOTES,PIPES_AS_CONCAT,STRICT_ALL_TABLES,NO_AUTO_VALUE_ON_ZERO,NO_ENGINE_SUBSTITUTION';
DELETE FROM `server_retainers`;
INSERT INTO `server_retainers` (`id`, `name`, `actorClassId`, `cdIDOffset`, `placeName`, `conditions`, `level`) VALUES
(1001, 'Wienta', 3001101, 0, 142, 0, 1),
(1002, 'Edmont', 3002101, 0, 133, 0, 1),
(1003, 'Lyngsath', 3003101, 0, 132, 0, 1);
