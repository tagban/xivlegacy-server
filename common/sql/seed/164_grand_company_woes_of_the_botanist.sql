-- Woes of the Botanist (Gcg303), the Twin Adder's errand for the
-- Botanists' Guild (scripts/lua/quests/gcg/gcg303.lua). Enie already
-- stands in the guild in Gridania. This adds, south and east of
-- Humblehearth (Central Shroud, zone 150):
--
-- * The overfed ladybugs that have stripped the herb field, on the floor
--   of the ravine there.
-- * Enie, come out to see the field for herself.
-- * The fretful moogle who blames her fertilizer for it all (a client
--   class with no class path until now).
--
-- Heights checked in the test client.
--
-- Idempotent: UPDATE guarded, INSERTs OR IGNORE on id. No schema change.

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
WHERE "id" = 1001838
  AND ("classPath" = '' OR "classPath" IS NULL);

INSERT OR IGNORE INTO "server_spawn_locations"
    ("id", "actorClassId", "uniqueId", "zoneId", "privateAreaName", "privateAreaLevel",
     "positionX", "positionY", "positionZ", "rotation", "actorState", "animationId", "customDisplayName")
VALUES
    (27868, 1001806, 'gcg303_enie',          150, '', 0,  -60.40, -2.70, -452.20,  2.40, 0, 0, null),
    (27869, 1001838, 'gcg303_fretful_moogle', 150, '', 0,  -57.50, -1.50, -449.50, -2.40, 0, 0, null);

INSERT OR IGNORE INTO "server_battlenpc_pools" ("poolId", "actorClassId", "name", "genusId", "currentJob", "combatSkill", "combatDelay", "combatDmgMult", "aggroType", "immunity", "linkType", "spellListId", "skillListId") VALUES
    (30127, 2103904, 'Ladybug', 38, 0, 1, 4200, 1.0, 1, 0, 0, 0, 0);

INSERT OR IGNORE INTO "server_battlenpc_groups" ("groupId", "poolId", "scriptName", "minLevel", "maxLevel", "respawnTime", "hp", "mp", "dropListId", "allegiance", "spawnType", "animationId", "actorState", "privateAreaName", "privateAreaLevel", "zoneId") VALUES
    (30140, 30127, 'gcg303_ladybug', 38, 40, 60, 1200, 0, 0, 0, 0, 0, 0, '', 0, 150);

INSERT OR IGNORE INTO "server_battlenpc_spawn_locations" ("bnpcId", "customDisplayName", "groupId", "positionX", "positionY", "positionZ", "rotation") VALUES
    (3572, 'gcg303_ladybug', 30140, -54.5, 0.1, -462.5, 0.5),
    (3573, 'gcg303_ladybug', 30140, -47.0, 2.0, -472.0, 1.5),
    (3574, 'gcg303_ladybug', 30140, -52.0, 0.6, -466.0, 2.5),
    (3575, 'gcg303_ladybug', 30140, -64.0, -3.5, -438.0, 3.5),
    (3576, 'gcg303_ladybug', 30140, -56.0, -2.0, -436.0, 4.5),
    (3577, 'gcg303_ladybug', 30140, -50.0, -0.5, -446.0, 5.5);
