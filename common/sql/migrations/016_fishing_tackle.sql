-- Which bait or lure each fish takes (DummyCommand.lua: a fish bites only on
-- tackle it takes; a fish with no rows takes anything). Rows come from the
-- game-data file gamedata_fishing_tackle.sql.
CREATE TABLE IF NOT EXISTS `gamedata_fishing_tackle` (
    `itemCatalogId` INT UNSIGNED NOT NULL,
    `tackleCatalogId` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`itemCatalogId`, `tackleCatalogId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
