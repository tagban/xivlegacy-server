-- server_zones_spawnlocations: game data, 20 rows. Reloaded whole when this file changes.
SET SESSION sql_mode = 'ANSI_QUOTES,PIPES_AS_CONCAT,STRICT_ALL_TABLES,NO_AUTO_VALUE_ON_ZERO,NO_ENGINE_SUBSTITUTION';
DELETE FROM `server_zones_spawnlocations`;
INSERT INTO `server_zones_spawnlocations` (`id`, `zoneId`, `privateAreaName`, `spawnType`, `spawnX`, `spawnY`, `spawnZ`, `spawnRotation`) VALUES
(1, 155, NULL, 15, 58.92, 4.0, -1219.07, 0.52),
(2, 133, NULL, 15, -444.266, 39.518, 191.0, 1.9),
(3, 175, NULL, 15, -230.0, 186.0, -3.9, 0.0),
(4, 193, NULL, 15, 0.016, 10.35, -36.91, 0.025),
(5, 166, NULL, 15, 356.09, 3.74, -701.62, -1.4),
(6, 184, NULL, 15, 5.36433, 196.0, 133.656, -2.84938),
(7, 128, NULL, 15, -8.48, 45.36, 139.5, 2.02),
(8, 230, 'PrivateAreaMasterPast', 15, -838.1, 6.0, 231.94, 1.1),
(9, 193, NULL, 16, -5.0, 16.35, 6.0, 0.5),
(10, 166, NULL, 16, 356.09, 3.74, -701.62, -1.4),
(11, 244, NULL, 15, 0.048, 0.0, -5.737, 0.0),
(12, 244, NULL, 15, -160.048, 0.0, -165.737, 0.0),
(13, 244, NULL, 15, 160.048, 0.0, 154.263, 0.0),
(14, 150, NULL, 15, 333.271, 5.889, -943.275, 0.794),
(15, 133, NULL, 15, -8.062, 45.429, 139.364, 2.955),
(16, 170, NULL, 15, -27.015, 181.798, -79.72, 2.513),
(17, 184, NULL, 16, -24.34, 192.0, 34.22, 0.78),
(18, 184, NULL, 15, -24.34, 192.0, 34.22, 0.78),
(19, 184, NULL, 15, -22.0, 196.0, 87.0, 1.8),
(20, 177, NULL, 15, 2.0, 2.0, 2.0, 0.0);
