-- Seasonal events (settings/events.toml).
-- server_events: a GM's `!event <name> <on|off|auto>` override, kept over
-- restarts. No row (or "auto") means the event follows its date windows.
CREATE TABLE IF NOT EXISTS `server_events` (
    `name` VARCHAR(32) NOT NULL,
    `mode` VARCHAR(8) NOT NULL,
    PRIMARY KEY (`name`)
);

-- server_spawn_location_events: spawns that belong to an event. They are
-- sent to players only while the event runs. A spawn with no row here is
-- always sent.
CREATE TABLE IF NOT EXISTS `server_spawn_location_events` (
    `spawnId` INT UNSIGNED NOT NULL,
    `eventName` VARCHAR(32) NOT NULL,
    PRIMARY KEY (`spawnId`)
);
