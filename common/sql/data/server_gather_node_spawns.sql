-- server_gather_node_spawns: game data, 15 rows. Reloaded whole when this file changes.
SET SESSION sql_mode = 'ANSI_QUOTES,PIPES_AS_CONCAT,STRICT_ALL_TABLES,NO_AUTO_VALUE_ON_ZERO,NO_ENGINE_SUBSTITUTION';
DELETE FROM `server_gather_node_spawns`;
INSERT INTO `server_gather_node_spawns` (`id`, `actorClassId`, `uniqueId`, `zoneId`, `privateAreaName`, `privateAreaLevel`, `positionX`, `positionY`, `positionZ`, `rotation`, `harvestNodeId`, `harvestType`) VALUES
(100, 1200052, 'mine_black_brush_1', 170, '', 0, -14.63, 200.29, -509.5, 1.05, 2010, 22002),
(101, 1200052, 'mine_black_brush_2', 170, '', 0, 5.5, 199.64, -529.63, 0.52, 2010, 22002),
(102, 1200052, 'mine_black_brush_3', 170, '', 0, 47.24, 200.52, -535.13, -0.26, 2010, 22002),
(103, 1200052, 'mine_drybone_1', 171, '', 0, 1229.41, 263.55, -594.83, 0.4, 2011, 22002),
(104, 1200052, 'mine_drybone_2', 171, '', 0, 1257.6, 264.06, -598.79, -0.12, 2011, 22002),
(105, 1200052, 'mine_drybone_3', 171, '', 0, 1284.0, 263.64, -588.12, -0.65, 2011, 22002),
(106, 1200052, 'mine_horizon_s_edge_1', 172, '', 0, -1300.6, 56.68, -198.96, -0.24, 2012, 22002),
(107, 1200052, 'mine_horizon_s_edge_2', 172, '', 0, -1275.7, 55.79, -185.16, -0.77, 2012, 22002),
(108, 1200052, 'mine_horizon_s_edge_3', 172, '', 0, -1261.04, 59.48, -160.76, -1.29, 2012, 22002),
(109, 1200052, 'mine_halatali_1', 171, '', 0, 1641.74, 260.25, -267.61, -0.89, 2013, 22002),
(110, 1200052, 'mine_halatali_2', 171, '', 0, 1653.32, 259.12, -241.6, -1.41, 2013, 22002),
(111, 1200052, 'mine_halatali_3', 171, '', 0, 1650.35, 259.84, -213.29, -1.94, 2013, 22002),
(112, 1200052, 'mine_nophica_s_wells_1', 172, '', 0, -810.02, 88.68, 373.26, -1.54, 2014, 22002),
(113, 1200052, 'mine_nophica_s_wells_2', 172, '', 0, -816.43, 92.49, 401.0, -2.06, 2014, 22002),
(114, 1200052, 'mine_nophica_s_wells_3', 172, '', 0, -848.91, 91.38, 427.78, -2.84, 2014, 22002);
