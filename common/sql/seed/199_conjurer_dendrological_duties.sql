-- Cnj200 Dendrological Duties (scripts/lua/quests/cnj/cnj200.lua): the
-- Conjurers' Guild's welcome, which had no script.
--
-- 1. Brother Telent: the quest's go-between, whose class (1000504) ships
--    stripped (classPath '', no spawn). He gets the class setup Soileine
--    uses and a spot near her in Stillglade Fane.
-- 2. The clearing east of the Blue Badger Gate: the stripped class 1090507
--    (classPath '', no spawn, no other reference) becomes a push circle
--    there, disabled until the quest turns it on. The position comes from
--    the cnj20020 scene's actor tracks.
-- 3. The fight (content Cnj20001): an alpha coywolf (class 2201409) and
--    three rabid coywolves (class 2201408), weak by design.
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
WHERE "id" = 1000504 AND ("classPath" = '' OR "classPath" IS NULL);

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
WHERE "id" = 1090507 AND ("classPath" = '' OR "classPath" IS NULL);

INSERT OR IGNORE INTO "server_spawn_locations"
    ("id", "actorClassId", "uniqueId", "zoneId", "privateAreaName", "privateAreaLevel",
     "positionX", "positionY", "positionZ", "rotation", "actorState", "animationId", "customDisplayName")
VALUES
    (29022, 1000504, 'cnj200_telent', 206, '', 0, -352.5, 6.23, -1703.5, -2.37, 0, 0, null),
    (29023, 1090507, 'cnj200_clearing_trigger', 150, '', 0, 726.0, 31.8, -849.0, 0.00, 0, 0, null);

INSERT OR IGNORE INTO "server_battlenpc_pools" ("poolId", "actorClassId", "name", "genusId", "currentJob", "combatSkill", "combatDelay", "combatDmgMult", "aggroType", "immunity", "linkType", "spellListId", "skillListId") VALUES
    (30217, 2201409, 'cnj200_alpha_coywolf', 3, 0, 1, 5000, 0.2, 0, 0, 0, 0, 0),
    (30218, 2201408, 'cnj200_rabid_coywolf', 3, 0, 1, 5000, 0.15, 0, 0, 0, 0, 0);

INSERT OR IGNORE INTO "server_battlenpc_groups" ("groupId", "poolId", "scriptName", "minLevel", "maxLevel", "respawnTime", "hp", "mp", "dropListId", "allegiance", "spawnType", "animationId", "actorState", "privateAreaName", "privateAreaLevel", "zoneId") VALUES
    (30317, 30217, 'cnj200_alpha_coywolf', 18, 18, 0, 240, 0, 0, 0, 16, 0, 0, '', 0, 150),
    (30318, 30218, 'cnj200_rabid_coywolf', 16, 16, 0, 130, 0, 0, 0, 16, 0, 0, '', 0, 150);

INSERT OR IGNORE INTO "server_battlenpc_spawn_locations" ("bnpcId", "customDisplayName", "groupId", "positionX", "positionY", "positionZ", "rotation") VALUES
    (3936, 'cnj200_alpha_coywolf', 30317, 732.0, 31.8, -855.0, 0.0),
    (3937, 'cnj200_rabid_coywolf', 30318, 735.0, 31.8, -850.0, 0.0),
    (3938, 'cnj200_rabid_coywolf', 30318, 728.0, 31.8, -858.0, 0.0),
    (3939, 'cnj200_rabid_coywolf', 30318, 736.0, 31.8, -857.0, 0.0);
