-- Thm300 Revelry in Rivalry (scripts/lua/quests/thm/thm300.lua): the
-- Thaumaturges' Guild's second assignment, which had no script.
--
-- 1. The overweening thaumaturge, your rival novice, whose class (1000607)
--    ships stripped (classPath '', no spawn). She gets the class setup
--    Keeper Yayake uses and a corner of the guild hall.
-- 2. The grass flat south of Camp Bearded Rock: the stripped class 1090508
--    (classPath '', no spawn, no other reference) becomes a push circle
--    there, disabled until the quest turns it on. Heights here and below
--    were walked in the client.
-- 3. The fight (content Thm30001): an ignis fatuus (class 2201603), weak by
--    design.
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
WHERE "id" = 1000607 AND ("classPath" = '' OR "classPath" IS NULL);

UPDATE "gamedata_actor_class" SET
    "classPath" = '/Chara/Npc/Populace/PopulaceStandard',
    "propertyFlags" = 1,
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
WHERE "id" = 1090508 AND ("classPath" = '' OR "classPath" IS NULL);

INSERT OR IGNORE INTO "server_spawn_locations"
    ("id", "actorClassId", "uniqueId", "zoneId", "privateAreaName", "privateAreaLevel",
     "positionX", "positionY", "positionZ", "rotation", "actorState", "animationId", "customDisplayName")
VALUES
    (29024, 1090508, 'thm300_runner_meadow_trigger', 128, '', 0, 48.3, 43.2, 226.4, 0.00, 0, 0, null),
    (29025, 1000607, 'thm300_overweening_thaumaturge', 209, '', 0, -299.0, 206.0, 226.5, 2.40, 0, 0, null);

INSERT OR IGNORE INTO "server_battlenpc_pools" ("poolId", "actorClassId", "name", "genusId", "currentJob", "combatSkill", "combatDelay", "combatDmgMult", "aggroType", "immunity", "linkType", "spellListId", "skillListId") VALUES
    (30219, 2201603, 'thm300_ignis_fatuus', 64, 0, 1, 5000, 0.25, 0, 0, 0, 0, 0);

INSERT OR IGNORE INTO "server_battlenpc_groups" ("groupId", "poolId", "scriptName", "minLevel", "maxLevel", "respawnTime", "hp", "mp", "dropListId", "allegiance", "spawnType", "animationId", "actorState", "privateAreaName", "privateAreaLevel", "zoneId") VALUES
    (30319, 30219, 'thm300_ignis_fatuus', 28, 28, 0, 600, 0, 0, 0, 16, 0, 0, '', 0, 128);

INSERT OR IGNORE INTO "server_battlenpc_spawn_locations" ("bnpcId", "customDisplayName", "groupId", "positionX", "positionY", "positionZ", "rotation") VALUES
    (3940, 'thm300_ignis_fatuus', 30319, 70.9, 42.59, 227.8, -1.57);
