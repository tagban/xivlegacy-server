-- United We Stand (Gcl106, Gcg106, Gcu106), the Grand Companies' assault on
-- Castrum Novum (scripts/lua/quests/gc/gc106.lua). Merlwyb and Storm Marshal
-- Slafyrsyn already stand in the Coral Tower, Kan-E-Senna and Cid at
-- Stillglade Fane, Raubahn on the Royal Promenade, the doors to each (Zanthael,
-- Kinnison, Mumutano) and the marshals in their headquarters. This adds:
--
-- * Castrum Novum's transmission tower (zone 251): the client's layout
--   lak0Dungeon01 and Mor Dhona's zone class, which the zone row lacked.
-- * Jagged Crest Cave, northwest of Camp Brittlebark (Mor Dhona, zone 190):
--   Flame Commander Ryder, Serpent Commander Yarborough, Storm Commander
--   Rhiki and Quinquerol on the cave floor around the aetherial gate, and a
--   trigger at the foot of the rock the gate stands on. Walking up to it asks
--   to enter Castrum Novum.
-- * Cid Garlond beside Merlwyb in the stateroom (zone 230) and beside Raubahn
--   on the Royal Promenade (zone 209).
-- * The tower's defenders, spawned into each copy by
--   SimpleContentCastrumNovum: an elite triarius, bestiarius and speculator,
--   a magitek vanguard, and the lunar transmitter itself (the client's
--   ObjectBeaconGcx105 class; it neither moves nor strikes back).
--   spawnType 1 keeps them out of the open world.
--
-- Heights checked in the test client. Gc?106 follows Gc?105.
--
-- Idempotent: UPDATEs guarded, INSERTs OR IGNORE on id. No schema change.

UPDATE "gamedata_quests" SET "prerequisite" = 111431 WHERE "id" = 111432 AND "prerequisite" = 0;
UPDATE "gamedata_quests" SET "prerequisite" = 111631 WHERE "id" = 111632 AND "prerequisite" = 0;
UPDATE "gamedata_quests" SET "prerequisite" = 111831 WHERE "id" = 111832 AND "prerequisite" = 0;

UPDATE "server_zones" SET "zoneName" = 'lak0Dungeon01', "classPath" = '/Area/Zone/ZoneMasterLakL0'
WHERE "id" = 251 AND ("zoneName" IS NULL OR "zoneName" = '');

-- The cave's gate asks with the raid guides' own prompt, which only their
-- class (InstanceRaidGuide) carries.
UPDATE "gamedata_actor_class" SET
    "classPath" = '/Chara/Npc/Populace/InstanceRaidGuide/InstanceRaidGuide',
    "eventConditions" = '{
  "pushWithCircleEventConditions": [
    {
      "isEnabled": "false",
      "radius": "4.0",
      "outwards": "false",
      "silent": "false",
      "conditionName": "pushDefault"
    }
  ]
}'
WHERE "id" = 1090342 AND ("classPath" = '' OR "classPath" IS NULL);

UPDATE "gamedata_actor_class" SET "classPath" = '/Chara/Npc/Monster/Object/ObjectBeaconGcx105'
WHERE "id" = 2210801 AND ("classPath" = '' OR "classPath" IS NULL);

INSERT OR IGNORE INTO "server_spawn_locations"
    ("id", "actorClassId", "uniqueId", "zoneId", "privateAreaName", "privateAreaLevel",
     "positionX", "positionY", "positionZ", "rotation", "actorState", "animationId", "customDisplayName")
VALUES
    (27834, 1001815, 'gc106_ryder',            190, '', 0,  -359.60, -16.10,   -34.60, -1.99, 0, 0, null),
    (27835, 1001808, 'gc106_yarborough',       190, '', 0,  -370.00, -16.70,   -39.40,  1.12, 0, 0, null),
    (27836, 1001810, 'gc106_rhiki',            190, '', 0,  -360.00, -15.50,   -39.40, -1.12, 0, 0, null),
    (27837, 1001809, 'gc106_quinquerol',       190, '', 0,  -355.00, -16.10,   -34.50, -1.82, 0, 0, null),
    (27838, 1090342, 'gc106_cave_gate',        190, '', 0,  -364.80, -16.00,   -41.50,  0.00, 0, 0, null),
    (27839, 1001572, 'gc106_cid_stateroom',    230, '', 0,  -620.00,  43.00,   -63.00,  2.36, 0, 0, null),
    (27840, 1001572, 'gc106_cid_promenade',    209, '', 0,  -106.00, 223.00,   204.30,  3.14, 0, 0, null);

INSERT OR IGNORE INTO "server_battlenpc_pools" ("poolId", "actorClassId", "name", "genusId", "currentJob", "combatSkill", "combatDelay", "combatDmgMult", "aggroType", "immunity", "linkType", "spellListId", "skillListId") VALUES
    (30110, 2280046, 'Elite Triarius',    29, 0, 1, 4200, 1.0, 1, 0, 0, 0, 0),
    (30111, 2280047, 'Elite Bestiarius',  29, 0, 1, 4200, 1.0, 1, 0, 0, 0, 0),
    (30112, 2280049, 'Elite Speculator',  29, 0, 1, 4200, 1.0, 1, 0, 0, 0, 0),
    (30113, 2209001, 'Magitek Vanguard',  29, 0, 1, 4600, 1.2, 1, 0, 0, 0, 0),
    (30114, 2210801, 'Magitek Transmitter', 29, 0, 0, 60000, 0.0, 0, 0, 0, 0, 0);

-- The transmitter stays put.
INSERT OR IGNORE INTO "server_battlenpc_pool_mods" ("poolId", "modId", "modVal", "isMobMod") VALUES
    (30114, 15, 1, 1);

INSERT OR IGNORE INTO "server_battlenpc_groups" ("groupId", "poolId", "scriptName", "minLevel", "maxLevel", "respawnTime", "hp", "mp", "dropListId", "allegiance", "spawnType", "animationId", "actorState", "privateAreaName", "privateAreaLevel", "zoneId") VALUES
    (30121, 30110, 'gc106_triarius',    46, 46, 0, 2000, 0, 0, 0, 1, 0, 0, '', 0, 251),
    (30122, 30111, 'gc106_bestiarius',  46, 46, 0, 2000, 0, 0, 0, 1, 0, 0, '', 0, 251),
    (30123, 30112, 'gc106_speculator',  46, 46, 0, 1800, 0, 0, 0, 1, 0, 0, '', 0, 251),
    (30124, 30113, 'gc106_vanguard',    47, 47, 0, 5000, 0, 0, 0, 1, 0, 0, '', 0, 251),
    (30125, 30114, 'gc106_transmitter', 47, 47, 0, 6000, 0, 0, 0, 1, 0, 0, '', 0, 251);

INSERT OR IGNORE INTO "server_battlenpc_spawn_locations" ("bnpcId", "customDisplayName", "groupId", "positionX", "positionY", "positionZ", "rotation") VALUES
    (3528, 'gc106_triarius',    30121, -5.0,  1.30, 19.5,  3.14),
    (3529, 'gc106_bestiarius',  30122,  5.0,  1.30, 19.5,  3.14),
    (3530, 'gc106_speculator',  30123,  0.0,  1.78, 29.5,  3.14),
    (3531, 'gc106_vanguard',    30124, -4.0, -0.95, 37.7,  3.14),
    (3532, 'gc106_transmitter', 30125,  0.0, -2.17, 45.5,  3.14);
