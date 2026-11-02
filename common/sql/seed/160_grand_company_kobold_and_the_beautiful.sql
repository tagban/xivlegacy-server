-- Kobold and the Beautiful (Gcl304), Lilina's errand to the U'Ghamaro Mines
-- (scripts/lua/quests/gcl/gcl304.lua). Lilina already stands at Mealvaan's
-- Gate. This adds:
--
-- * Chief Storm Sergeant Kurtz Nolan at Camp Iron Lake (Upper La Noscea,
--   zone 135), his class (1001697) given the populace class it lacks.
-- * The mine mouth northeast of the camp, walked into to enter the mines (zone
--   137) while the quest sends you there, and the way back out from the
--   Central Furnaces, where you arrive. The mines have no other way in yet.
-- * The three metal works tested with the coblyn choler: the Central
--   Furnaces door, the door under the Burner Loft, and the door of Dome 2610.
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
WHERE "id" = 1001697 AND ("classPath" = '' OR "classPath" IS NULL);

UPDATE "gamedata_actor_class" SET
    "classPath" = '/Chara/Npc/Populace/PopulaceStandard',
    "eventConditions" = '{
  "pushWithCircleEventConditions": [
    {
      "isEnabled": "false",
      "radius": "3.0",
      "outwards": "false",
      "silent": "false",
      "conditionName": "pushDefault"
    }
  ]
}'
WHERE "id" IN (1090347) AND ("classPath" = '' OR "classPath" IS NULL);

UPDATE "gamedata_actor_class" SET
    "classPath" = '/Chara/Npc/Populace/PopulaceStandard',
    "eventConditions" = '{
  "pushWithCircleEventConditions": [
    {
      "isEnabled": "false",
      "radius": "2.0",
      "outwards": "false",
      "silent": "false",
      "conditionName": "pushDefault"
    }
  ]
}'
WHERE "id" IN (1090348) AND ("classPath" = '' OR "classPath" IS NULL);

UPDATE "gamedata_actor_class" SET
    "classPath" = '/Chara/Npc/Populace/PopulaceStandard',
    "eventConditions" = '{
  "pushWithCircleEventConditions": [
    {
      "isEnabled": "false",
      "radius": "2.0",
      "outwards": "false",
      "silent": "false",
      "conditionName": "pushDefault"
    }
  ]
}'
WHERE "id" IN (1090349, 1090350, 1090351) AND ("classPath" = '' OR "classPath" IS NULL);

INSERT OR IGNORE INTO "server_spawn_locations"
    ("id", "actorClassId", "uniqueId", "zoneId", "privateAreaName", "privateAreaLevel",
     "positionX", "positionY", "positionZ", "rotation", "actorState", "animationId", "customDisplayName")
VALUES
    (27861, 1001697, 'gcl304_nolan',          135, '', 0,  -276.00,  77.60, -2248.00,  2.60, 0, 0, null),
    (27862, 1090347, 'gcl304_mine_mouth',     135, '', 0,    94.40,  61.60, -2713.50,  0.00, 0, 0, null),
    (27863, 1090348, 'gcl304_mine_exit',      137, '', 0,    86.50, -10.60, -2955.00,  0.00, 0, 0, null),
    (27864, 1090349, 'gcl304_furnaces_door',  137, '', 0,    82.10, -11.80, -2950.20,  0.00, 0, 0, null),
    (27865, 1090350, 'gcl304_loft_door',      137, '', 0,   128.70, -11.90, -2927.90,  0.00, 0, 0, null),
    (27866, 1090351, 'gcl304_dome_door',      137, '', 0,   145.60, -12.55, -2975.70,  0.00, 0, 0, null);
