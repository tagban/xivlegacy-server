-- Gone with the Wind (Gcg304), Alaire's errand to Coerthas
-- (scripts/lua/quests/gcg/gcg304.lua). Alaire already stands in Gridania.
-- This adds, in the Coerthas central highlands (zone 143):
--
-- * Chief Serpent Sergeant Liflin Gulin at Camp Dragonhead, his class
--   (1001698) given the populace class it lacks.
-- * Three places in the outer works of Natalan, east of the camp, where
--   parts of the new Ixali war balloon lie: by the supply crates, west of
--   the barricade, and on the slope south of it.
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
WHERE "id" = 1001698 AND ("classPath" = '' OR "classPath" IS NULL);

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
WHERE "id" IN (1090352, 1090353, 1090354) AND ("classPath" = '' OR "classPath" IS NULL);

INSERT OR IGNORE INTO "server_spawn_locations"
    ("id", "actorClassId", "uniqueId", "zoneId", "privateAreaName", "privateAreaLevel",
     "positionX", "positionY", "positionZ", "rotation", "actorState", "animationId", "customDisplayName")
VALUES
    (27870, 1001698, 'gcg304_liflin_gulin',     143, '', 0,   219.00, 302.50, -262.00,  0.00, 0, 0, null),
    (27871, 1090352, 'gcg304_balloon_panel',    143, '', 0,   508.50, 303.30, -213.50,  0.00, 0, 0, null),
    (27872, 1090353, 'gcg304_balloon_plume',    143, '', 0,   495.20, 302.80, -222.70,  0.00, 0, 0, null),
    (27873, 1090354, 'gcg304_balloon_eye',      143, '', 0,   515.20, 303.20, -233.00,  0.00, 0, 0, null);
