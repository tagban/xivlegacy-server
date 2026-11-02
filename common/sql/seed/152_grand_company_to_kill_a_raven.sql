-- To Kill a Raven (Gcl107, Gcg107, Gcu107), the Grand Companies' last quest
-- (scripts/lua/quests/gc/gc107.lua). Kinnison already stands before the
-- Lotus Stand, Kan-E-Senna and Cid at Stillglade Fane, the Archons in the
-- clearing before it (seed 150), the officers and marshals in each
-- headquarters. This adds:
--
-- * Merlwyb and Raubahn at the Lotus Stand (zone 206) for the emergency
--   council, beside Kan-E-Senna.
-- * Gregory, the Enterprise's steward, and Cid in the clearing before the
--   Lotus Stand, which stands in for the airship landing.
-- * A trigger south and east of Camp Glory (Coerthas Eastern Lowlands, zone
--   145), on the hillside path where the floating isles show in the sky.
-- * Nael van Darnus (battle npc 3533, class 2210901, WhiteGeneralNormal)
--   for Rivenroad (zone 257), spawned into each copy by
--   SimpleContentRivenroad on the Allagan dais at the zone's heart (floor
--   y 0); spawnType 1 keeps him out of the open world.
--
-- Heights checked in the test client. Gc?107 follows Gc?106.
--
-- Idempotent: UPDATEs guarded, INSERTs OR IGNORE on id. No schema change.

UPDATE "gamedata_quests" SET "prerequisite" = 111432 WHERE "id" = 111433 AND "prerequisite" = 0;
UPDATE "gamedata_quests" SET "prerequisite" = 111632 WHERE "id" = 111633 AND "prerequisite" = 0;
UPDATE "gamedata_quests" SET "prerequisite" = 111832 WHERE "id" = 111833 AND "prerequisite" = 0;

UPDATE "gamedata_actor_class" SET
    "classPath" = '/Chara/Npc/Populace/PopulaceStandard',
    "propertyFlags" = 19,
    "eventConditions" = '{
  "talkEventConditions": [
    {
      "unknown1": 4,
      "unknown2": 0,
      "conditionName": "talkDefault"
    }
  ],
  "noticeEventConditions": [
    {
      "unknown1": 0,
      "unknown2": 1,
      "conditionName": "noticeEvent"
    }
  ]
}'
WHERE "id" = 1002046 AND ("classPath" = '' OR "classPath" IS NULL);

UPDATE "gamedata_actor_class" SET
    "classPath" = '/Chara/Npc/Populace/PopulaceStandard',
    "eventConditions" = '{
  "pushWithCircleEventConditions": [
    {
      "isEnabled": "false",
      "radius": "6.0",
      "outwards": "false",
      "silent": "false",
      "conditionName": "pushDefault"
    }
  ]
}'
WHERE "id" = 1090343 AND ("classPath" = '' OR "classPath" IS NULL);

INSERT OR IGNORE INTO "server_spawn_locations"
    ("id", "actorClassId", "uniqueId", "zoneId", "privateAreaName", "privateAreaLevel",
     "positionX", "positionY", "positionZ", "rotation", "actorState", "animationId", "customDisplayName")
VALUES
    (27841, 1001568, 'gc107_merlwyb',          206, '', 0,  -340.50,   6.82, -1705.00,  1.57, 0, 0, null),
    (27842, 1060008, 'gc107_raubahn',          206, '', 0,  -347.00,   6.82, -1705.00,  1.57, 0, 0, null),
    (27843, 1002046, 'gc107_gregory',          206, '', 0,  -200.00,  22.59, -1613.50,  1.57, 0, 0, null),
    (27844, 1001572, 'gc107_cid_clearing',     206, '', 0,  -205.00,  22.12, -1610.50,  1.57, 0, 0, null),
    (27845, 1090343, 'gc107_camp_glory',       145, '', 0,  1580.00, 205.89,   851.75,  0.00, 0, 0, null);

INSERT OR IGNORE INTO "server_battlenpc_pools" ("poolId", "actorClassId", "name", "genusId", "currentJob", "combatSkill", "combatDelay", "combatDmgMult", "aggroType", "immunity", "linkType", "spellListId", "skillListId") VALUES
    (30115, 2210901, 'Nael van Darnus', 29, 0, 1, 3600, 1.5, 1, 0, 0, 0, 0);

INSERT OR IGNORE INTO "server_battlenpc_groups" ("groupId", "poolId", "scriptName", "minLevel", "maxLevel", "respawnTime", "hp", "mp", "dropListId", "allegiance", "spawnType", "animationId", "actorState", "privateAreaName", "privateAreaLevel", "zoneId") VALUES
    (30126, 30115, 'nael_van_darnus', 50, 50, 0, 15000, 0, 0, 0, 1, 0, 0, '', 0, 257);

INSERT OR IGNORE INTO "server_battlenpc_spawn_locations" ("bnpcId", "customDisplayName", "groupId", "positionX", "positionY", "positionZ", "rotation") VALUES
    (3533, 'nael_van_darnus', 30126, 0.0, 0.0, 6.0, 3.14);
