-- A Weaver and a Mummer (Gcu303), Cahernaut's errand to the front
-- (scripts/lua/quests/gcu/gcu303.lua). Cahernaut already stands in Sunsilk
-- Tapestries. This adds:
--
-- * The foot of the mesa northeast of Nophica's Wells (Western Thanalan,
--   zone 172), walked into to start the duty.
-- * The imperial scouts, spawned by the duty (SimpleContentGcu30301): two
--   secutors and a sagittarius from the level 40 imperial pools of seed 143.
--
-- Heights checked in the test client.
--
-- Idempotent: UPDATEs guarded, INSERTs OR IGNORE on id. No schema change.

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
WHERE "id" = 1090344 AND ("classPath" = '' OR "classPath" IS NULL);

INSERT OR IGNORE INTO "server_spawn_locations"
    ("id", "actorClassId", "uniqueId", "zoneId", "privateAreaName", "privateAreaLevel",
     "positionX", "positionY", "positionZ", "rotation", "actorState", "animationId", "customDisplayName")
VALUES
    (27850, 1090344, 'gcu303_mesa', 172, '', 0, -754.00, 91.30, 279.00, 0.00, 0, 0, null);

-- spawnType 1 keeps them out of the open world: the duty spawns them.
INSERT OR IGNORE INTO "server_battlenpc_groups" ("groupId", "poolId", "scriptName", "minLevel", "maxLevel", "respawnTime", "hp", "mp", "dropListId", "allegiance", "spawnType", "animationId", "actorState", "privateAreaName", "privateAreaLevel", "zoneId") VALUES
    (30129, 30103, 'gcu303_secutor',     40, 41, 0, 1800, 0, 0, 0, 1, 0, 0, '', 0, 172),
    (30130, 30105, 'gcu303_sagittarius', 40, 41, 0, 1500, 0, 0, 0, 1, 0, 0, '', 0, 172);

INSERT OR IGNORE INTO "server_battlenpc_spawn_locations" ("bnpcId", "customDisplayName", "groupId", "positionX", "positionY", "positionZ", "rotation") VALUES
    (3543, 'gcu303_secutor',     30129, -751.4, 91.3, 281.8, -2.5),
    (3544, 'gcu303_secutor',     30129, -752.5, 91.6, 286.1, -2.8),
    (3545, 'gcu303_sagittarius', 30130, -756.0, 91.3, 275.5, -2.2);
