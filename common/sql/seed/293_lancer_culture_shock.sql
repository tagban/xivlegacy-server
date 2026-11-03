-- Lnc300 Culture Shock (scripts/lua/quests/lnc/lnc300.lua): the Lancers'
-- Guild's rank 30 quest, which had no script.
--
-- 1. Dreues: the Ala Mhigan pugilist of the Platinum Mirage, whose class
--    (1000402) ships stripped (classPath '', no spawn). He gets the class
--    setup Gagaruna uses and a walked spot on the Mirage's lobby floor.
-- 2. The caravan road in the Central Shroud: the stripped class 1090509
--    (classPath '', no spawn, no other reference) becomes a push circle
--    there, disabled until the quest turns it on. The position comes from
--    the lnc30050/60/65 scenes' actor tracks, the height from the client's
--    ground mesh.
-- 3. The fight (content Lnc30001): three dreadwolves (class 2101403), weak
--    by design.
--
-- Idempotent: UPDATEs guarded on the value they fix, INSERTs OR IGNORE on id.

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
WHERE "id" = 1000402 AND ("classPath" = '' OR "classPath" IS NULL);

UPDATE "gamedata_actor_class" SET
    "classPath" = '/Chara/Npc/Populace/PopulaceStandard',
    "propertyFlags" = 1,
    "eventConditions" = '{
  "pushWithCircleEventConditions": [
    {
      "isEnabled": "false",
      "radius": "5.0",
      "outwards": "false",
      "silent": "false",
      "conditionName": "pushDefault"
    }
  ]
}'
WHERE "id" = 1090509 AND ("classPath" = '' OR "classPath" IS NULL);

INSERT OR IGNORE INTO "server_spawn_locations"
    ("id", "actorClassId", "uniqueId", "zoneId", "privateAreaName", "privateAreaLevel",
     "positionX", "positionY", "positionZ", "rotation", "actorState", "animationId", "customDisplayName")
VALUES
    (29026, 1090509, 'lnc300_caravan_road_trigger', 150, '', 0, 390.0, 6.35, 15.0, 0.00, 0, 0, null),
    (29027, 1000402, 'lnc300_dreues', 175, '', 0, -183.23, 190.10, 109.72, -1.60, 0, 0, null);

INSERT OR IGNORE INTO "server_battlenpc_pools" ("poolId", "actorClassId", "name", "genusId", "currentJob", "combatSkill", "combatDelay", "combatDmgMult", "aggroType", "immunity", "linkType", "spellListId", "skillListId") VALUES
    (30220, 2101403, 'lnc300_dreadwolf', 3, 0, 1, 4500, 0.2, 0, 0, 0, 0, 0);

INSERT OR IGNORE INTO "server_battlenpc_groups" ("groupId", "poolId", "scriptName", "minLevel", "maxLevel", "respawnTime", "hp", "mp", "dropListId", "allegiance", "spawnType", "animationId", "actorState", "privateAreaName", "privateAreaLevel", "zoneId") VALUES
    (30320, 30220, 'lnc300_dreadwolf', 27, 27, 0, 300, 0, 0, 0, 16, 0, 0, '', 0, 150);

INSERT OR IGNORE INTO "server_battlenpc_spawn_locations" ("bnpcId", "customDisplayName", "groupId", "positionX", "positionY", "positionZ", "rotation") VALUES
    (3941, 'lnc300_dreadwolf', 30320, 407.0, 4.2, 27.0, 0.0),
    (3942, 'lnc300_dreadwolf', 30320, 410.0, 4.45, 20.0, 0.0),
    (3943, 'lnc300_dreadwolf', 30320, 398.0, 4.6, 34.0, 0.0);
