-- Leve allowances (map-server/src/leve/allowance.rs): how many leves a
-- character may still take. Taking a regional, faction or Grand Company
-- leve (and retrying a failed one) spends one; `[leves]` in
-- settings/map.toml sets the refill (1.0: 4 every 12 real hours) and the
-- cap (1.0: 99). `allowances` is the count when `stamp` (unix seconds) was
-- last brought up to date; the server works out the refills since from the
-- stamp when it reads the row. A character with no row, which is every
-- character when this migration runs, holds the cap in force.
CREATE TABLE IF NOT EXISTS characters_leve_allowances (
    characterId BIGINT NOT NULL PRIMARY KEY,
    allowances  INT NOT NULL DEFAULT 99,
    stamp       BIGINT NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
