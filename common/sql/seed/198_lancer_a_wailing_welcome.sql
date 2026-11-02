-- Lnc200 A Wailing Welcome (scripts/lua/quests/lnc/lnc200.lua): the
-- Lancers' Guild's welcome, which had no script.
--
-- 1. Lifemend Stump: J'moldva marks the chigoe-infested ground on your map.
--    The stripped class 1090506 (classPath '', no spawn, no other
--    reference) becomes a push circle there, disabled until the quest turns
--    it on. The position comes from the lnc20020 scene's actor tracks.
-- 2. The cull (content Lnc20001): four chigoes (class 2105612), weak by
--    design.
--
-- Idempotent: UPDATE guarded on the value it fixes, INSERTs OR IGNORE on id.

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
WHERE "id" = 1090506 AND ("classPath" = '' OR "classPath" IS NULL);

INSERT OR IGNORE INTO "server_spawn_locations"
    ("id", "actorClassId", "uniqueId", "zoneId", "privateAreaName", "privateAreaLevel",
     "positionX", "positionY", "positionZ", "rotation", "actorState", "animationId", "customDisplayName")
VALUES
    (29021, 1090506, 'lnc200_lifemend_stump_trigger', 150, '', 0, -641.2, 6.1, -987.9, 0.00, 0, 0, null);

INSERT OR IGNORE INTO "server_battlenpc_pools" ("poolId", "actorClassId", "name", "genusId", "currentJob", "combatSkill", "combatDelay", "combatDmgMult", "aggroType", "immunity", "linkType", "spellListId", "skillListId") VALUES
    (30216, 2105612, 'lnc200_chigoe', 36, 0, 1, 5000, 0.15, 0, 0, 0, 0, 0);

INSERT OR IGNORE INTO "server_battlenpc_groups" ("groupId", "poolId", "scriptName", "minLevel", "maxLevel", "respawnTime", "hp", "mp", "dropListId", "allegiance", "spawnType", "animationId", "actorState", "privateAreaName", "privateAreaLevel", "zoneId") VALUES
    (30316, 30216, 'lnc200_chigoe', 17, 17, 0, 140, 0, 0, 0, 16, 0, 0, '', 0, 150);

INSERT OR IGNORE INTO "server_battlenpc_spawn_locations" ("bnpcId", "customDisplayName", "groupId", "positionX", "positionY", "positionZ", "rotation") VALUES
    (3932, 'lnc200_chigoe', 30316, -646.0, 4.3, -1001.0, 0.0),
    (3933, 'lnc200_chigoe', 30316, -633.0, 4.3, -1000.0, 0.0),
    (3934, 'lnc200_chigoe', 30316, -649.0, 4.3, -995.0, 0.0),
    (3935, 'lnc200_chigoe', 30316, -631.0, 4.3, -994.0, 0.0);
