-- Monster Points: earned only by playing as a monster (Monster Mode), spent
-- at the Monster Points vendors. The balance is a currency item in the
-- money package (99); this table keeps the earning caps and the lifetime
-- total. `dayStamp` is the UTC day number (unix days), `weekStamp` the
-- week number (weeks start on Monday, UTC).
CREATE TABLE IF NOT EXISTS characters_monster_points (
    characterId BIGINT NOT NULL PRIMARY KEY,
    earnedToday INT NOT NULL DEFAULT 0,
    dayStamp    INT NOT NULL DEFAULT 0,
    earnedWeek  INT NOT NULL DEFAULT 0,
    weekStamp   INT NOT NULL DEFAULT 0,
    lifetime    BIGINT NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- A spawn that wears another actor class's model and gear (its look in
-- gamedata_actor_appearance): the Monster Points vendors are shop NPCs in
-- a Qiqirn's, a Moogle's and a Goblin's body. Game data in
-- data/server_spawn_looks.sql.
CREATE TABLE IF NOT EXISTS `server_spawn_looks` (
    `spawnId` INT UNSIGNED NOT NULL PRIMARY KEY,
    `appearanceClassId` INT UNSIGNED NOT NULL
);
