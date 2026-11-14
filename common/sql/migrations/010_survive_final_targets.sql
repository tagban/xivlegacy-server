-- Survive leves whose sheet row names no final targets: the targets to
-- fight once the hold ends (display-name id and count, up to two kinds).
-- 0 means none; a Survive leve with no targets at all is won by the hold.
ALTER TABLE server_guildleve_survive
    ADD COLUMN finalMob1 INT UNSIGNED NOT NULL DEFAULT 0 AFTER holdUp,
    ADD COLUMN finalNum1 TINYINT UNSIGNED NOT NULL DEFAULT 0 AFTER finalMob1,
    ADD COLUMN finalMob2 INT UNSIGNED NOT NULL DEFAULT 0 AFTER finalNum1,
    ADD COLUMN finalNum2 TINYINT UNSIGNED NOT NULL DEFAULT 0 AFTER finalMob2;
