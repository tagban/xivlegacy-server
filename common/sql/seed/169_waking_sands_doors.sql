-- The Waking Sands' doors work without a quest (zone 181, private area
-- PrivateAreaMasterPast; seed 112 placed them).
--
-- Their push circles shipped switched off, and only Man200, Man206 and
-- Man304 switched them on while they needed a door. At any other time the
-- doors did nothing: a player sent to Minfilia by a later step, or who left
-- her office before taking Toll of the Warden (Man300), could not get back
-- in, and the entrance did not lead back out to Ul'dah.
--
-- The circles are now on by default. A quest that has a door in its step
-- still takes the push first; otherwise the door's override under
-- scripts/lua/unique/wil0Event01/privatearea/ warps the player through
-- (scripts/lua/wakingsands.lua).
--
-- Idempotent: the UPDATE only flips the circle's own flag. No schema change.

UPDATE "gamedata_actor_class" SET
    "eventConditions" = replace("eventConditions", '"isEnabled": "false"', '"isEnabled": "true"')
WHERE "id" IN (1090160, 1090161, 1090162) AND "eventConditions" LIKE '%"pushWithCircleEventConditions"%';
