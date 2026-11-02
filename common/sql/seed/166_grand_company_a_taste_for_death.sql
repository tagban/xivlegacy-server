-- A Taste for Death (Gcg305), the Oak Atrium's plea to the Order of the
-- Twin Adder (scripts/lua/quests/gcg/gcg305.lua). Zuzupoja already stands
-- in the Oak Atrium. This adds, in the clearing west of the Thousand Maws
-- of Toto-Rak (South Shroud, zone 154):
--
-- * The shriekers swarming where the botanists were last heard from.
-- * The Yellow Serpents who arrive after the fight: High Commander
--   Quinquerol Flutaint, Serpent Commander Vevina Yarborough and Serpent
--   Captain Tall Oak (second spawns; they also stand in the Central Shroud
--   and Gridania for other quests).
--
-- Heights checked in the test client.
--
-- Idempotent: INSERTs OR IGNORE on id. No schema change.

INSERT OR IGNORE INTO "server_spawn_locations"
    ("id", "actorClassId", "uniqueId", "zoneId", "privateAreaName", "privateAreaLevel",
     "positionX", "positionY", "positionZ", "rotation", "actorState", "animationId", "customDisplayName")
VALUES
    (27874, 1001809, 'gcg305_quinquerol',  154, '', 0,   727.10, -11.32,  629.10,  0.80, 0, 0, null),
    (27875, 1001808, 'gcg305_yarborough',  154, '', 0,   723.10, -11.23,  633.10,  1.20, 0, 0, null),
    (27876, 1001807, 'gcg305_tall_oak',    154, '', 0,   731.10, -10.85,  633.10,  0.40, 0, 0, null);

INSERT OR IGNORE INTO "server_battlenpc_pools" ("poolId", "actorClassId", "name", "genusId", "currentJob", "combatSkill", "combatDelay", "combatDmgMult", "aggroType", "immunity", "linkType", "spellListId", "skillListId") VALUES
    (30128, 2105909, 'Shrieker', 14, 0, 1, 4200, 1.0, 1, 0, 0, 0, 0);

INSERT OR IGNORE INTO "server_battlenpc_groups" ("groupId", "poolId", "scriptName", "minLevel", "maxLevel", "respawnTime", "hp", "mp", "dropListId", "allegiance", "spawnType", "animationId", "actorState", "privateAreaName", "privateAreaLevel", "zoneId") VALUES
    (30141, 30128, 'gcg305_shrieker', 48, 50, 60, 1600, 0, 0, 0, 0, 0, 0, '', 0, 154);

INSERT OR IGNORE INTO "server_battlenpc_spawn_locations" ("bnpcId", "customDisplayName", "groupId", "positionX", "positionY", "positionZ", "rotation") VALUES
    (3578, 'gcg305_shrieker', 30141, 734.0, -11.85, 599.3, 0.5),
    (3579, 'gcg305_shrieker', 30141, 751.0, -11.00, 599.3, 2.5),
    (3580, 'gcg305_shrieker', 30141, 739.1, -11.10, 623.1, 1.0),
    (3581, 'gcg305_shrieker', 30141, 754.9, -11.32, 615.3, 3.0),
    (3582, 'gcg305_shrieker', 30141, 727.1, -11.85, 611.1, 0.0),
    (3583, 'gcg305_shrieker', 30141, 761.1, -10.80, 605.1, 4.0);
