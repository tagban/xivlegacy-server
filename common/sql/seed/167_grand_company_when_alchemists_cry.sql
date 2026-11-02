-- When Alchemists Cry (Gcu304), Berthar's errand to Zahar'ak
-- (scripts/lua/quests/gcu/gcu304.lua). Berthar already stands in the
-- Phrontistery in Ul'dah. This adds, in Southern Thanalan (zone 174):
--
-- * Flame Sergeant Jandonaut Fouillel at Camp Broken Water, where the
--   client's default-talk table places him (his class, 1001699, given the
--   populace class it lacks).
-- * The three piles of drake feed at the Amalj'aa camp of Zahar'ak: two by
--   the entrance on the west side, and one among the structures beyond.
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
WHERE "id" = 1001699 AND ("classPath" = '' OR "classPath" IS NULL);

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
WHERE "id" IN (1090355, 1090356, 1090357) AND ("classPath" = '' OR "classPath" IS NULL);

INSERT OR IGNORE INTO "server_spawn_locations"
    ("id", "actorClassId", "uniqueId", "zoneId", "privateAreaName", "privateAreaLevel",
     "positionX", "positionY", "positionZ", "rotation", "actorState", "animationId", "customDisplayName")
VALUES
    (27877, 1001699, 'gcu304_jandonaut',      174, '', 0,  1704.00, 296.00,   999.00,  1.57, 0, 0, null),
    (27878, 1090355, 'gcu304_feed_entrance1', 174, '', 0,  2100.50, 295.90,  1028.70,  0.00, 0, 0, null),
    (27879, 1090356, 'gcu304_feed_entrance2', 174, '', 0,  2115.40, 299.10,  1038.50,  0.00, 0, 0, null),
    (27880, 1090357, 'gcu304_feed_beyond',    174, '', 0,  2190.60, 299.80,  1028.50,  0.00, 0, 0, null);
