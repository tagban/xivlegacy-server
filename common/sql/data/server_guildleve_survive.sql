-- server_guildleve_survive: Survive leves' hold phase, 9 rows. Reloaded whole when this file changes.
-- holdSeconds: how long the area is held before the final targets appear.
-- holdSecondsRecorded: 1 when a 1.0 account gives the time, 0 for the 5-minute default.
-- holdMob: display-name id of the monster that attacks during the hold; holdUp: how many at once.
-- finalMob1/2, finalNum1/2: final targets for a leve whose sheet row names none (0: none).
-- A leve with no final targets in either place ("monster horde" leves) is won when the hold ends.
-- 12528 Sweet Revenge: Ill-tempered pteroc for 5 minutes (recorded), then the Cavern efts.
-- 12508 All Nine Ivies is a Stage: Bile gnats until the timer ends (time not recorded), then the
-- Toxic flytrap and Plasma spark.
-- The other 7 use stand-in values (user decision, 2026-11-14): a 5-minute hold against the camp's
-- local monster near level 40, 3 at a time, then the sheet's final targets.
--   Camp Bald Knoll (10906-10908): Toxic toad. 10907 then the Dreamtoad (sheet).
--     10908: 3 Brimstone bombs and 3 Fachan (a guide's walkthrough; the sheet names none).
--   Camp Iron Lake (10927, 10928): Young raptor. 10927 then 2 Drifting anemones (sheet).
--   Camp Nine Ivies (12507): Bile gnat, as 12508. Treespeak (12527): Ill-tempered pteroc, as 12528.
--   10906, 10928, 12507, 12527 are horde leves: the hold alone wins them.
SET SESSION sql_mode = 'ANSI_QUOTES,PIPES_AS_CONCAT,STRICT_ALL_TABLES,NO_AUTO_VALUE_ON_ZERO,NO_ENGINE_SUBSTITUTION';
DELETE FROM `server_guildleve_survive`;
INSERT INTO `server_guildleve_survive` (`guildleveId`, `holdSeconds`, `holdSecondsRecorded`, `holdMob`, `holdUp`, `finalMob1`, `finalNum1`, `finalMob2`, `finalNum2`) VALUES
(10906, 300, 0, 3103101, 3, 0, 0, 0, 0),
(10907, 300, 0, 3103101, 3, 0, 0, 0, 0),
(10908, 300, 0, 3103101, 3, 3201602, 3, 3201701, 3),
(10927, 300, 0, 3100211, 3, 0, 0, 0, 0),
(10928, 300, 0, 3100211, 3, 0, 0, 0, 0),
(12507, 300, 0, 3200602, 3, 0, 0, 0, 0),
(12508, 300, 0, 3200602, 3, 0, 0, 0, 0),
(12527, 300, 0, 3200107, 3, 0, 0, 0, 0),
(12528, 300, 1, 3200107, 3, 0, 0, 0, 0);
