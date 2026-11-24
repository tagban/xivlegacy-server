-- Anima, the 1.x teleport currency (map-server/src/runtime/anima.rs). A
-- character recovers 1 anima every 4 hours of real time, logged in or not,
-- up to 100. `anima` is the amount when `stamp` (unix seconds) was last
-- brought up to date; the server works out the regained anima from the
-- stamp when it reads the row. A character with no row has a full 100.
CREATE TABLE IF NOT EXISTS characters_anima (
    characterId BIGINT NOT NULL PRIMARY KEY,
    anima       INT NOT NULL DEFAULT 100,
    stamp       BIGINT NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
