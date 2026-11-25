-- Monster drop lists (map-server src/drops.rs). One row per item a list can
-- drop. A monster uses its group's dropListId, or, when that is 0, the list
-- whose id is its actor class id. Rows come from the game-data file
-- server_drop_lists.sql. chance and hqChance are per 10000 (10000 = always);
-- rarity 0 common, 1 uncommon, 2 rare (rare rows take the host's
-- [drops] rare_drop_percent on top of drop_rate_percent). itemId 1000001 is
-- gil: quantityMin..quantityMax gil, at the host's gil_drop_percent.
CREATE TABLE IF NOT EXISTS `server_drop_lists` (
    `dropListId` INT UNSIGNED NOT NULL,
    `itemId` INT UNSIGNED NOT NULL,
    `quantityMin` INT UNSIGNED NOT NULL DEFAULT 1,
    `quantityMax` INT UNSIGNED NOT NULL DEFAULT 1,
    `chance` SMALLINT UNSIGNED NOT NULL,
    `rarity` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `hqChance` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`dropListId`, `itemId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
