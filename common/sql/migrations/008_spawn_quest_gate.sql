-- Quest-gated spawns: a spawn row listed here is sent only to a player who
-- holds one of its quests. It is for private areas that several Echoes
-- share (zone 209 PrivateAreaMasterPast 5), so one quest's scene doesn't
-- stand in another's. A spawn with no rows here is sent to everyone.
CREATE TABLE IF NOT EXISTS `server_spawn_location_quests` (
    `spawnId` INT UNSIGNED NOT NULL,
    `questId` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`spawnId`, `questId`)
);
