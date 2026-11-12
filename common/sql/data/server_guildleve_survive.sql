-- server_guildleve_survive: Survive leves' hold phase, 2 rows. Reloaded whole when this file changes.
-- holdSeconds: how long the area is held before the sheet's final targets appear.
-- holdSecondsRecorded: 1 when a 1.0 account gives the time, 0 for the 5-minute default.
-- holdMob: display-name id of the monster that attacks during the hold; holdUp: how many at once.
-- 12528 Sweet Revenge: Ill-tempered pteroc for 5 minutes (recorded), then the Cavern efts.
-- 12508 All Nine Ivies is a Stage: Bile gnats until the timer ends (time not recorded), then the
-- Toxic flytrap and Plasma spark.
SET SESSION sql_mode = 'ANSI_QUOTES,PIPES_AS_CONCAT,STRICT_ALL_TABLES,NO_AUTO_VALUE_ON_ZERO,NO_ENGINE_SUBSTITUTION';
DELETE FROM `server_guildleve_survive`;
INSERT INTO `server_guildleve_survive` (`guildleveId`, `holdSeconds`, `holdSecondsRecorded`, `holdMob`, `holdUp`) VALUES
(12508, 300, 0, 3200602, 3),
(12528, 300, 1, 3200107, 3);
