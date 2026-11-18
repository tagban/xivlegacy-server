-- Monster Mode log: what players do while playing as a monster, for the
-- move tracker and /reports. One row per event; rows are only inserted.
--   event   enter    took a monster's body
--           exit     let go (outcome = off, ko, zone, logout, class, gear)
--           move     a monster move resolved (outcome = hit, miss, heal, buff)
--           refused  a monster move was refused (textId = the client line)
--           verdict  a tester's mark on a move (outcome = ok, bad; note)
-- `mobClassId` is the monster's actor class, `actionId` the move.
CREATE TABLE IF NOT EXISTS log_monster_mode (
    id          BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    at          BIGINT NOT NULL,
    characterId BIGINT NOT NULL,
    event       VARCHAR(16) NOT NULL,
    mobClassId  BIGINT NOT NULL DEFAULT 0,
    level       INT NOT NULL DEFAULT 0,
    actionId    BIGINT NOT NULL DEFAULT 0,
    targetClassId BIGINT NOT NULL DEFAULT 0,
    outcome     VARCHAR(16) NOT NULL DEFAULT '',
    amount      BIGINT NOT NULL DEFAULT 0,
    statusId    BIGINT NOT NULL DEFAULT 0,
    animationId BIGINT NOT NULL DEFAULT 0,
    textId      BIGINT NOT NULL DEFAULT 0,
    zoneId      BIGINT NOT NULL DEFAULT 0,
    note        VARCHAR(255) NOT NULL DEFAULT '',
    KEY log_monster_mode_character (characterId, at),
    KEY log_monster_mode_action (actionId, event),
    KEY log_monster_mode_at (at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
