-- gamedata_regional_leves: game data, 6 rows. Reloaded whole when this file changes.
SET SESSION sql_mode = 'ANSI_QUOTES,PIPES_AS_CONCAT,STRICT_ALL_TABLES,NO_AUTO_VALUE_ON_ZERO,NO_ENGINE_SUBSTITUTION';
DELETE FROM `gamedata_regional_leves`;
INSERT INTO `gamedata_regional_leves` (`id`, `leveType`, `plateId`, `borderId`, `recommendedClass`, `issuingLocation`, `guildleveLocation`, `deliveryDisplayName`, `region`, `objectiveTargetId1`, `objectiveQuantity1`, `recommendedLevel1`, `rewardItemId1`, `rewardQuantity1`, `rewardGil1`, `objectiveTargetId2`, `objectiveQuantity2`, `recommendedLevel2`, `rewardItemId2`, `rewardQuantity2`, `rewardGil2`, `objectiveTargetId3`, `objectiveQuantity3`, `recommendedLevel3`, `rewardItemId3`, `rewardQuantity3`, `rewardGil3`, `objectiveTargetId4`, `objectiveQuantity4`, `recommendedLevel4`, `rewardItemId4`, `rewardQuantity4`, `rewardGil4`) VALUES
(130001, 1, 0, 0, 30, 0, 0, 0, 1001, 10001001, 5, 1, 0, 0, 200, 10001001, 10, 10, 0, 0, 500, 10001001, 15, 20, 0, 0, 1200, 10001001, 20, 30, 0, 0, 2500),
(130002, 1, 0, 0, 33, 0, 0, 0, 2012, 10008007, 5, 1, 0, 0, 200, 10008007, 10, 10, 0, 0, 500, 10008007, 15, 20, 0, 0, 1200, 10008007, 20, 30, 0, 0, 2500),
(130003, 1, 0, 0, 30, 0, 0, 0, 3006, 10001006, 5, 1, 0, 0, 200, 10001006, 10, 10, 0, 0, 500, 10001006, 15, 20, 0, 0, 1200, 10001006, 20, 30, 0, 0, 2500),
(140001, 2, 12483, 0, 2, 0, 0, 0, 1001, 5000035, 3, 1, 0, 0, 300, 5000035, 5, 10, 0, 0, 700, 5000035, 8, 20, 0, 0, 1800, 5000035, 12, 30, 0, 0, 3500),
(140002, 2, 12484, 0, 2, 0, 0, 0, 2012, 5000076, 3, 1, 0, 0, 300, 5000076, 5, 10, 0, 0, 700, 5000076, 8, 20, 0, 0, 1800, 5000076, 12, 30, 0, 0, 3500),
(140003, 2, 12481, 0, 2, 0, 0, 0, 3006, 5000091, 3, 1, 0, 0, 300, 5000091, 5, 10, 0, 0, 700, 5000091, 8, 20, 0, 0, 1800, 5000091, 12, 30, 0, 0, 3500);
