-- Different Strokes (Gcu302), the Immortal Flames' errand for the
-- Coliseum (scripts/lua/quests/gcu/gcu302.lua). Galeren already stands in
-- the Coliseum. This adds:
--
-- * Flame Sergeant Cotter on Pearl Lane (zone 175), across from
--   the stalls.
-- * The Ul'dahn Beastcleavers northeast of Camp Drybone (Eastern Thanalan,
--   zone 171): Flame Lieutenant Westin and Flame Privates Salpa Hazalpa and
--   Goodwife, on the flat north of the camp.
-- * The hellhounds that ambush you there (open world, as the hounds that
--   would have met the Beastcleavers' march).
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
WHERE "id" IN (1001685, 1001686, 1001687, 1001688)
  AND ("classPath" = '' OR "classPath" IS NULL);

INSERT OR IGNORE INTO "server_spawn_locations"
    ("id", "actorClassId", "uniqueId", "zoneId", "privateAreaName", "privateAreaLevel",
     "positionX", "positionY", "positionZ", "rotation", "actorState", "animationId", "customDisplayName")
VALUES
    (27846, 1001685, 'gcu302_cotter',          175, '', 0,    12.00, 196.00,   170.00,  0.00, 0, 0, null),
    (27847, 1001686, 'gcu302_westin',          171, '', 0,  1335.60, 264.00,  -722.20,  2.36, 0, 0, null),
    (27848, 1001687, 'gcu302_salpa_hazalpa',   171, '', 0,  1332.00, 264.00,  -725.00,  1.57, 0, 0, null),
    (27849, 1001688, 'gcu302_goodwife',        171, '', 0,  1339.00, 264.00,  -726.00,  3.14, 0, 0, null);

INSERT OR IGNORE INTO "server_battlenpc_pools" ("poolId", "actorClassId", "name", "genusId", "currentJob", "combatSkill", "combatDelay", "combatDmgMult", "aggroType", "immunity", "linkType", "spellListId", "skillListId") VALUES
    (30117, 2109801, 'Hellhound', 3, 0, 1, 4000, 1.0, 1, 0, 0, 0, 0);

INSERT OR IGNORE INTO "server_battlenpc_groups" ("groupId", "poolId", "scriptName", "minLevel", "maxLevel", "respawnTime", "hp", "mp", "dropListId", "allegiance", "spawnType", "animationId", "actorState", "privateAreaName", "privateAreaLevel", "zoneId") VALUES
    (30128, 30117, 'gcu302_hellhound', 26, 28, 60, 700, 0, 0, 0, 0, 0, 0, '', 0, 171);

INSERT OR IGNORE INTO "server_battlenpc_spawn_locations" ("bnpcId", "customDisplayName", "groupId", "positionX", "positionY", "positionZ", "rotation") VALUES
    (3540, 'gcu302_hellhound', 30128, 1364.6, 264.0, -711.6, 3.0),
    (3541, 'gcu302_hellhound', 30128, 1373.7, 264.0, -726.8, 2.0),
    (3542, 'gcu302_hellhound', 30128, 1348.0, 264.0, -754.0, 1.0);
