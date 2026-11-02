-- The Cove (Gcl301), Clifton's errand for the Fishermen's Guild
-- (scripts/lua/quests/gcl/gcl301.lua). Clifton already stands in the guild.
-- This adds the dart slugs on the sandy cove west of Aleport (Western La
-- Noscea, zone 129), below the cliffs where the giant crabs feed: open
-- world, respawning, so anyone on the quest can thin them.
--
-- Heights checked in the test client (walked: y 2.5-4.0 on the beach).
--
-- Idempotent: INSERTs OR IGNORE on id. No schema change.

INSERT OR IGNORE INTO "server_battlenpc_pools" ("poolId", "actorClassId", "name", "genusId", "currentJob", "combatSkill", "combatDelay", "combatDmgMult", "aggroType", "immunity", "linkType", "spellListId", "skillListId") VALUES
    (30120, 2204211, 'Dart Slug', 21, 0, 1, 4200, 1.0, 1, 0, 0, 0, 0);

INSERT OR IGNORE INTO "server_battlenpc_groups" ("groupId", "poolId", "scriptName", "minLevel", "maxLevel", "respawnTime", "hp", "mp", "dropListId", "allegiance", "spawnType", "animationId", "actorState", "privateAreaName", "privateAreaLevel", "zoneId") VALUES
    (30133, 30120, 'gcl301_dart_slug', 25, 27, 60, 650, 0, 0, 0, 0, 0, 0, '', 0, 129);

INSERT OR IGNORE INTO "server_battlenpc_spawn_locations" ("bnpcId", "customDisplayName", "groupId", "positionX", "positionY", "positionZ", "rotation") VALUES
    (3549, 'gcl301_dart_slug', 30133, -1577.4, 4.0, -641.5, 0.5),
    (3550, 'gcl301_dart_slug', 30133, -1591.5, 3.9, -634.1, 1.5),
    (3551, 'gcl301_dart_slug', 30133, -1597.7, 2.5, -618.9, 2.5),
    (3552, 'gcl301_dart_slug', 30133, -1579.9, 3.0, -622.6, -1.0),
    (3553, 'gcl301_dart_slug', 30133, -1561.1, 3.1, -628.0, -2.0),
    (3554, 'gcl301_dart_slug', 30133, -1545.3, 2.8, -624.5, 3.0);
