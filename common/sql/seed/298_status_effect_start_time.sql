-- When each saved status effect started, and when it was saved (seed 298).
--
-- characters_statuseffect kept only an effect's full duration, so an effect
-- restored at login started over with all of it. Like LandSandBoat's
-- char_effects (timestamp + duration), the row now says when the effect
-- started (startTime) and when it was last saved (savedAt), both unix
-- seconds. At login an effect resumes with the time it had left when it was
-- saved; one flagged TICK_OFFLINE (1 << 30) kept running while its owner was
-- away and is dropped if its time ran out. 0 = saved before this seed: the
-- effect is restored with its full duration, as before.
ALTER TABLE characters_statuseffect ADD COLUMN startTime INTEGER NOT NULL DEFAULT 0;
ALTER TABLE characters_statuseffect ADD COLUMN savedAt INTEGER NOT NULL DEFAULT 0;
