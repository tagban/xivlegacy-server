-- The Pen Is Mightier Than the Spear (Gcg302), the Twin Adder's errand for
-- the Wood Wailers (scripts/lua/quests/gcg/gcg302.lua). Dhemdaeg already
-- stands in the Wailing Barracks. This adds:
--
-- * Challinie by the Rootslake (South Shroud, zone 154), come to put down
--   the beast the wood whispered of.
-- * That beast: a lone dreadwolf on the lake shore.
--
-- Both stand a few yalms east of Com0g5's Thancred and Urianger (seed 129)
-- so they don't overlap them. Heights checked in the test client.
--
-- Idempotent: INSERTs OR IGNORE on id. No schema change.

INSERT OR IGNORE INTO "server_spawn_locations"
    ("id", "actorClassId", "uniqueId", "zoneId", "privateAreaName", "privateAreaLevel",
     "positionX", "positionY", "positionZ", "rotation", "actorState", "animationId", "customDisplayName")
VALUES
    (27867, 1000956, 'gcg302_challinie', 154, '', 0,  1450.10, -8.97, 1156.00, -1.20, 0, 0, null);

INSERT OR IGNORE INTO "server_battlenpc_pools" ("poolId", "actorClassId", "name", "genusId", "currentJob", "combatSkill", "combatDelay", "combatDmgMult", "aggroType", "immunity", "linkType", "spellListId", "skillListId") VALUES
    (30126, 2101403, 'Dreadwolf', 3, 0, 1, 4200, 1.0, 1, 0, 0, 0, 0);

INSERT OR IGNORE INTO "server_battlenpc_groups" ("groupId", "poolId", "scriptName", "minLevel", "maxLevel", "respawnTime", "hp", "mp", "dropListId", "allegiance", "spawnType", "animationId", "actorState", "privateAreaName", "privateAreaLevel", "zoneId") VALUES
    (30139, 30126, 'gcg302_dreadwolf', 26, 27, 60, 1500, 0, 0, 0, 0, 0, 0, '', 0, 154);

INSERT OR IGNORE INTO "server_battlenpc_spawn_locations" ("bnpcId", "customDisplayName", "groupId", "positionX", "positionY", "positionZ", "rotation") VALUES
    (3571, 'gcg302_dreadwolf', 30139, 1443.6, -11.3, 1158.2, 1.9);
