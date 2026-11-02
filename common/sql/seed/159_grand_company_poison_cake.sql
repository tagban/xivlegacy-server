-- It's a Piece of Cake to Bake a Poison Cake (Gcl303), R'sushmo's errand
-- after Kikkiroon Irongut (scripts/lua/quests/gcl/gcl303.lua). R'sushmo
-- already stands in the Bismarck. This adds, west of the Cedarwood
-- aetheryte (La Noscea, zone 128):
--
-- * The clearing walked into to start the duty.
-- * Kikkiroon Irongut the foe, spawned by the duty (SimpleContentGcl30301),
--   and Kikkiroon the penitent who stands there after, his event class
--   (1001811) given the populace class it lacks. The duty is entered by
--   warp, which keeps the penitent out of the fight.
-- * Storm Commander Rhiki, a second spawn of his Gcl102 class, looking on.
--
-- Heights checked in the test client.
--
-- Idempotent: UPDATEs guarded, INSERTs OR IGNORE on id. No schema change.

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
WHERE "id" = 1001811 AND ("classPath" = '' OR "classPath" IS NULL);

UPDATE "gamedata_actor_class" SET
    "classPath" = '/Chara/Npc/Populace/PopulaceStandard',
    "eventConditions" = '{
  "pushWithCircleEventConditions": [
    {
      "isEnabled": "false",
      "radius": "8.0",
      "outwards": "false",
      "silent": "false",
      "conditionName": "pushDefault"
    }
  ]
}'
WHERE "id" = 1090346 AND ("classPath" = '' OR "classPath" IS NULL);

INSERT OR IGNORE INTO "server_spawn_locations"
    ("id", "actorClassId", "uniqueId", "zoneId", "privateAreaName", "privateAreaLevel",
     "positionX", "positionY", "positionZ", "rotation", "actorState", "animationId", "customDisplayName")
VALUES
    (27858, 1001810, 'gcl303_rhiki',      128, '', 0,  565.50, 53.17, 15.85,  1.85, 0, 0, null),
    (27859, 1090346, 'gcl303_cedarwood',  128, '', 0,  565.50, 53.17, 15.85,  0.00, 0, 0, null),
    (27860, 1001811, 'gcl303_kikkiroon',  128, '', 0,  564.50, 53.14, 11.60,  0.90, 0, 0, null);

INSERT OR IGNORE INTO "server_battlenpc_pools" ("poolId", "actorClassId", "name", "genusId", "currentJob", "combatSkill", "combatDelay", "combatDmgMult", "aggroType", "immunity", "linkType", "spellListId", "skillListId") VALUES
    (30123, 2206305, 'Kikkiroon Irongut', 25, 0, 1, 4200, 1.0, 0, 0, 0, 0, 0);

-- spawnType 1 keeps him out of the open world: the duty spawns him.
INSERT OR IGNORE INTO "server_battlenpc_groups" ("groupId", "poolId", "scriptName", "minLevel", "maxLevel", "respawnTime", "hp", "mp", "dropListId", "allegiance", "spawnType", "animationId", "actorState", "privateAreaName", "privateAreaLevel", "zoneId") VALUES
    (30136, 30123, 'gcl303_kikkiroon', 40, 41, 0, 3500, 0, 0, 0, 1, 0, 0, '', 0, 128);

INSERT OR IGNORE INTO "server_battlenpc_spawn_locations" ("bnpcId", "customDisplayName", "groupId", "positionX", "positionY", "positionZ", "rotation") VALUES
    (3559, 'gcl303_kikkiroon', 30136, 558.9, 51.6, 15.9, 1.57);
