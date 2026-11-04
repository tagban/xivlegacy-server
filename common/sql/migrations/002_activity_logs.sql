-- Activity logs: one row per change to a character, for reports and for
-- answering "where did my item go". `at` is unix seconds (UTC). Rows are
-- only ever inserted; nothing in the game reads them back.

CREATE TABLE log_sessions (
    id          BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    at          BIGINT NOT NULL,
    accountId   BIGINT NOT NULL DEFAULT 0,
    characterId BIGINT NOT NULL DEFAULT 0,
    event       VARCHAR(16) NOT NULL,   -- login, zone, logout
    zoneId      BIGINT NOT NULL DEFAULT 0,
    detail      VARCHAR(255) NOT NULL DEFAULT '',
    KEY log_sessions_character (characterId, at),
    KEY log_sessions_at (at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE log_items (
    id           BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    at           BIGINT NOT NULL,
    characterId  BIGINT NOT NULL,
    itemId       BIGINT NOT NULL,
    serverItemId BIGINT NOT NULL DEFAULT 0,
    quantity     BIGINT NOT NULL,       -- change: + gained, - lost
    itemPackage  INT NOT NULL DEFAULT 0,
    reason       VARCHAR(32) NOT NULL DEFAULT '',
    KEY log_items_character (characterId, at),
    KEY log_items_item (itemId, at),
    KEY log_items_at (at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE log_gil (
    id          BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    at          BIGINT NOT NULL,
    characterId BIGINT NOT NULL,
    delta       BIGINT NOT NULL,
    balance     BIGINT NOT NULL,
    reason      VARCHAR(32) NOT NULL DEFAULT '',
    KEY log_gil_character (characterId, at),
    KEY log_gil_at (at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE log_progress (
    id          BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    at          BIGINT NOT NULL,
    characterId BIGINT NOT NULL,
    kind        VARCHAR(16) NOT NULL,   -- exp, level, class, job
    classId     INT NOT NULL DEFAULT 0,
    value       BIGINT NOT NULL,
    KEY log_progress_character (characterId, at),
    KEY log_progress_at (at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE log_quests (
    id          BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    at          BIGINT NOT NULL,
    characterId BIGINT NOT NULL,
    kind        VARCHAR(8) NOT NULL,    -- quest, leve
    questId     BIGINT NOT NULL,
    event       VARCHAR(16) NOT NULL,   -- step, complete, remove, accept, abandon
    sequence    BIGINT NOT NULL DEFAULT 0,
    KEY log_quests_character (characterId, at),
    KEY log_quests_quest (questId, at),
    KEY log_quests_at (at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE log_combat (
    id          BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    at          BIGINT NOT NULL,
    characterId BIGINT NOT NULL,
    targetId    BIGINT NOT NULL DEFAULT 0,
    actionId    BIGINT NOT NULL DEFAULT 0,
    kind        VARCHAR(16) NOT NULL,   -- kill, death, damage, heal
    amount      BIGINT NOT NULL DEFAULT 0,
    zoneId      BIGINT NOT NULL DEFAULT 0,
    KEY log_combat_character (characterId, at),
    KEY log_combat_at (at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE log_gm (
    id          BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    at          BIGINT NOT NULL,
    characterId BIGINT NOT NULL,
    command     VARCHAR(64) NOT NULL,
    args        VARCHAR(1024) NOT NULL DEFAULT '',
    KEY log_gm_character (characterId, at),
    KEY log_gm_at (at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE log_trades (
    id              BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    at              BIGINT NOT NULL,
    fromCharacterId BIGINT NOT NULL,
    toCharacterId   BIGINT NOT NULL,
    kind            VARCHAR(16) NOT NULL,   -- trade, bazaar, retainer
    itemId          BIGINT NOT NULL DEFAULT 0,
    quantity        BIGINT NOT NULL DEFAULT 0,
    gil             BIGINT NOT NULL DEFAULT 0,
    KEY log_trades_from (fromCharacterId, at),
    KEY log_trades_to (toCharacterId, at),
    KEY log_trades_at (at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
