-- Oil Crisis (Gcl305), Syngsmyd's errand to Iron Lake
-- (scripts/lua/quests/gcl/gcl305.lua). Syngsmyd already stands at Naldiq &
-- Vymelli's. This adds the deadly nightshades on the grassy southern shore
-- of Iron Lake (Upper La Noscea, zone 135), north of Camp Iron Lake.
--
-- Heights checked in the test client.
--
-- Idempotent: INSERTs OR IGNORE on id. No schema change.

INSERT OR IGNORE INTO "server_battlenpc_pools" ("poolId", "actorClassId", "name", "genusId", "currentJob", "combatSkill", "combatDelay", "combatDmgMult", "aggroType", "immunity", "linkType", "spellListId", "skillListId") VALUES
    (30124, 2202714, 'Deadly Nightshade', 15, 0, 1, 4000, 1.0, 1, 0, 0, 0, 0);

INSERT OR IGNORE INTO "server_battlenpc_groups" ("groupId", "poolId", "scriptName", "minLevel", "maxLevel", "respawnTime", "hp", "mp", "dropListId", "allegiance", "spawnType", "animationId", "actorState", "privateAreaName", "privateAreaLevel", "zoneId") VALUES
    (30137, 30124, 'gcl305_nightshade', 48, 50, 60, 1500, 0, 0, 0, 0, 0, 0, '', 0, 135);

INSERT OR IGNORE INTO "server_battlenpc_spawn_locations" ("bnpcId", "customDisplayName", "groupId", "positionX", "positionY", "positionZ", "rotation") VALUES
    (3560, 'gcl305_nightshade', 30137, -192.3, 76.5, -2343.1, 0.5),
    (3561, 'gcl305_nightshade', 30137, -198.5, 77.1, -2345.4, 2.0),
    (3562, 'gcl305_nightshade', 30137, -189.5, 78.5, -2362.2, -1.0),
    (3563, 'gcl305_nightshade', 30137, -178.6, 75.6, -2352.1, 1.5),
    (3564, 'gcl305_nightshade', 30137, -172.4, 77.5, -2366.2, -2.5),
    (3565, 'gcl305_nightshade', 30137, -153.2, 74.3, -2380.5, 3.0);
