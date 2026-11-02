-- Exc200 Bloody Baptism (scripts/lua/quests/exc/exc200.lua): the
-- Marauders' Guild's welcome, which had no script.
--
-- 1. Swiftperch Tower near Aleport: Nunuba sends you there to cull its
--    lemmings. The stripped class 1090501 (classPath '', no spawn, no other
--    reference) becomes a push circle on the path up to the tower, where
--    exc20020 starts, disabled until the quest turns it on. Positions come
--    from the cutscenes (exc20020 arrival and lemmings).
-- 2. The hunt (content Exc20001): four tower lemmings (class 2204003, the
--    client's own LemmingScenarioMrdLv20), weak by design.
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
WHERE "id" = 1090501 AND ("classPath" = '' OR "classPath" IS NULL);

INSERT OR IGNORE INTO "server_spawn_locations"
    ("id", "actorClassId", "uniqueId", "zoneId", "privateAreaName", "privateAreaLevel",
     "positionX", "positionY", "positionZ", "rotation", "actorState", "animationId", "customDisplayName")
VALUES
    (29016, 1090501, 'exc200_swiftperch_tower_trigger', 129, '', 0, -799.6, 49.1, -674.8, 0.00, 0, 0, null);

INSERT OR IGNORE INTO "server_battlenpc_pools" ("poolId", "actorClassId", "name", "genusId", "currentJob", "combatSkill", "combatDelay", "combatDmgMult", "aggroType", "immunity", "linkType", "spellListId", "skillListId") VALUES
    (30213, 2204003, 'exc200_tower_lemming', 12, 0, 1, 5000, 0.15, 0, 0, 0, 0, 0);

INSERT OR IGNORE INTO "server_battlenpc_groups" ("groupId", "poolId", "scriptName", "minLevel", "maxLevel", "respawnTime", "hp", "mp", "dropListId", "allegiance", "spawnType", "animationId", "actorState", "privateAreaName", "privateAreaLevel", "zoneId") VALUES
    (30313, 30213, 'exc200_tower_lemming', 17, 17, 0, 140, 0, 0, 0, 16, 0, 0, '', 0, 129);

INSERT OR IGNORE INTO "server_battlenpc_spawn_locations" ("bnpcId", "customDisplayName", "groupId", "positionX", "positionY", "positionZ", "rotation") VALUES
    (3925, 'exc200_tower_lemming', 30313, -787.5, 45.4, -687.1, 0.0),
    (3926, 'exc200_tower_lemming', 30313, -782.3, 45.4, -685.6, 0.0),
    (3927, 'exc200_tower_lemming', 30313, -784.8, 45.4, -688.4, 0.0),
    (3928, 'exc200_tower_lemming', 30313, -788.1, 45.4, -689.3, 0.0);
