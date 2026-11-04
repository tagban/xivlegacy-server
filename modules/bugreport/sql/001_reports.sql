-- One player bug report (modules/bugreport). The files (screenshot, logs) are
-- in <folder>/<id>/ on the server (settings/bugreport.toml).
-- Times are unix seconds. nextTryAt holds i64::MAX while the client is still
-- sending the files, so every number column is BIGINT.
CREATE TABLE IF NOT EXISTS module_bugreport_reports (
    id BIGINT NOT NULL AUTO_INCREMENT,
    userId BIGINT NOT NULL,
    characterId BIGINT NOT NULL,
    characterName VARCHAR(255) NOT NULL,
    world VARCHAR(255) NOT NULL DEFAULT '',
    zoneId BIGINT NOT NULL,
    zoneName VARCHAR(255) NOT NULL DEFAULT '',
    posX DOUBLE NOT NULL DEFAULT 0,
    posY DOUBLE NOT NULL DEFAULT 0,
    posZ DOUBLE NOT NULL DEFAULT 0,
    rotation DOUBLE NOT NULL DEFAULT 0,
    message TEXT NOT NULL DEFAULT '',
    -- the attached file names, comma separated
    files TEXT NOT NULL DEFAULT '',
    createdAt BIGINT NOT NULL,
    -- publishing (web server): the GitHub issue's address once made, whether
    -- Discord has it, and when to try again after a failure
    githubIssue VARCHAR(255),
    discordSent BIGINT NOT NULL DEFAULT 0,
    attempts BIGINT NOT NULL DEFAULT 0,
    nextTryAt BIGINT NOT NULL DEFAULT 0,
    lastError TEXT,
    publishedAt BIGINT,
    PRIMARY KEY (id),
    KEY module_bugreport_reports_user (userId, createdAt),
    KEY module_bugreport_reports_pending (publishedAt)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
