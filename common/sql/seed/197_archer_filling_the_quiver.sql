-- Arc200 Filling the Quiver (scripts/lua/quests/arc/arc200.lua): the
-- Archers' Guild's welcome, which had no script.
--
-- Keelty, the partner the quest pairs you with, appears only in the
-- quest's cutscenes, so each meeting is a push circle where its scene
-- starts. The stripped classes 1090502-1090505 (classPath '', no spawn, no
-- other reference) become those circles, disabled until the quest turns
-- each on:
--   1090502 inside the Archers' Guild (arc20010)
--   1090503 Camp Emerald Moss (arc20020)
--   1090504 where the Ixal waits (arc20030, then content Arc20001)
--   1090505 where Keelty is found (arc20040)
-- Positions come from the scenes (actor tracks in arc20020/30/40).
-- The fight: an Ixali fencer (class 2106401) and two yarzon feeders (class
-- 2105501), weak by design.
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
WHERE "id" IN (1090502, 1090503, 1090504, 1090505) AND ("classPath" = '' OR "classPath" IS NULL);

INSERT OR IGNORE INTO "server_spawn_locations"
    ("id", "actorClassId", "uniqueId", "zoneId", "privateAreaName", "privateAreaLevel",
     "positionX", "positionY", "positionZ", "rotation", "actorState", "animationId", "customDisplayName")
VALUES
    (29017, 1090502, 'arc200_guild_inside_trigger', 206, '', 0, 237.7, 12.0, -1278.0, 0.00, 0, 0, null),
    (29018, 1090503, 'arc200_emerald_moss_trigger', 152, '', 0, -1045.7, 20.3, -1753.0, 0.00, 0, 0, null),
    (29019, 1090504, 'arc200_ixal_ground_trigger', 152, '', 0, -1571.0, 20.3, -1899.5, 0.00, 0, 0, null),
    (29020, 1090505, 'arc200_keelty_found_trigger', 152, '', 0, -1433.9, 20.5, -1774.9, 0.00, 0, 0, null);

INSERT OR IGNORE INTO "server_battlenpc_pools" ("poolId", "actorClassId", "name", "genusId", "currentJob", "combatSkill", "combatDelay", "combatDmgMult", "aggroType", "immunity", "linkType", "spellListId", "skillListId") VALUES
    (30214, 2106401, 'arc200_ixali_fencer', 24, 0, 1, 5000, 0.2, 0, 0, 0, 0, 0),
    (30215, 2105501, 'arc200_yarzon_feeder', 12, 0, 1, 5000, 0.15, 0, 0, 0, 0, 0);

INSERT OR IGNORE INTO "server_battlenpc_groups" ("groupId", "poolId", "scriptName", "minLevel", "maxLevel", "respawnTime", "hp", "mp", "dropListId", "allegiance", "spawnType", "animationId", "actorState", "privateAreaName", "privateAreaLevel", "zoneId") VALUES
    (30314, 30214, 'arc200_ixali_fencer', 18, 18, 0, 240, 0, 0, 0, 16, 0, 0, '', 0, 152),
    (30315, 30215, 'arc200_yarzon_feeder', 16, 16, 0, 130, 0, 0, 0, 16, 0, 0, '', 0, 152);

INSERT OR IGNORE INTO "server_battlenpc_spawn_locations" ("bnpcId", "customDisplayName", "groupId", "positionX", "positionY", "positionZ", "rotation") VALUES
    (3929, 'arc200_ixali_fencer', 30314, -1589.6, 20.7, -1908.2, 0.0),
    (3930, 'arc200_yarzon_feeder', 30315, -1586.0, 20.5, -1912.0, 0.0),
    (3931, 'arc200_yarzon_feeder', 30315, -1593.0, 20.5, -1904.0, 0.0);
