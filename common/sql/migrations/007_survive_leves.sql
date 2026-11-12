-- Survive leves (plate 20027): per-leve hold phase. A leve with a row here
-- runs (and is offered); the others stay off until their details are known.
CREATE TABLE IF NOT EXISTS `server_guildleve_survive` (
    `guildleveId` INT UNSIGNED NOT NULL,
    `holdSeconds` INT UNSIGNED NOT NULL,
    `holdSecondsRecorded` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `holdMob` INT UNSIGNED NOT NULL,
    `holdUp` TINYINT UNSIGNED NOT NULL DEFAULT 3,
    PRIMARY KEY (`guildleveId`)
);
