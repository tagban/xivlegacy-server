-- Duplicate spawn rows (#456): three spawns were listed twice with the same
-- class, zone and position, which put two actors on top of each other.
--   775   Gridania aetheryte 1280061 (zone 206), a copy of row 563.
--   2270  Man0g1 BTN trigger 1090046 (zone 206), a copy of row 553. The
--         quests find the trigger by class, so both copies got a push circle.
--   828   aetheryte 1280127 in zone 0, a copy of row 512.
-- None of them has quest, event, module, look or map-object rows. The data
-- file no longer lists them; this removes them from existing databases too.
DELETE FROM `server_spawn_locations` WHERE `id` IN (775, 2270, 828);
