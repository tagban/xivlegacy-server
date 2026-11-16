-- Quest-only gathering points: a gathering point listed here is shown to,
-- and can be used by, only a player who holds one of its quests at one of
-- its sequences (the step that sends them there). The crafting and gathering
-- guild quests' story items come from such points. A point with no rows
-- here is for everyone.
CREATE TABLE IF NOT EXISTS `server_gather_node_quests` (
    `spawnId` INT UNSIGNED NOT NULL,
    `questId` INT UNSIGNED NOT NULL,
    `sequence` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`spawnId`, `questId`, `sequence`)
);
