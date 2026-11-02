-- Challenge Accepted (Gcu305), I'Paghlo's errand to the Free Brigade's drill
-- ground (scripts/lua/quests/gcu/gcu305.lua). I'Paghlo already stands in the
-- Platinum Mirage. This adds:
--
-- * High Commander Ryder at the foot of the mesa south of Mythril Pit No. 8
--   (Eastern Thanalan, zone 171), a second spawn of his Gcu102 class.
-- * The ground before him, walked into to start the duty.
-- * The undead he hunts for sport there, spawned by the duty
--   (SimpleContentGcu30501): two zombie pikemen and a zombie mage.
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
WHERE "id" = 1090345 AND ("classPath" = '' OR "classPath" IS NULL);

INSERT OR IGNORE INTO "server_spawn_locations"
    ("id", "actorClassId", "uniqueId", "zoneId", "privateAreaName", "privateAreaLevel",
     "positionX", "positionY", "positionZ", "rotation", "actorState", "animationId", "customDisplayName")
VALUES
    (27851, 1001815, 'gcu305_ryder', 171, '', 0, 1332.00, 261.80, -165.20, 3.14, 0, 0, null),
    (27852, 1090345, 'gcu305_mesa',  171, '', 0, 1329.50, 256.50, -197.00, 0.00, 0, 0, null);

INSERT OR IGNORE INTO "server_battlenpc_pools" ("poolId", "actorClassId", "name", "genusId", "currentJob", "combatSkill", "combatDelay", "combatDmgMult", "aggroType", "immunity", "linkType", "spellListId", "skillListId") VALUES
    (30118, 2201801, 'Zombie Pikeman', 29, 0, 1, 4000, 1.0, 1, 0, 0, 0, 0),
    (30119, 2201803, 'Zombie Mage',    29, 0, 1, 4000, 1.0, 1, 0, 0, 0, 0);

-- spawnType 1 keeps them out of the open world: the duty spawns them.
INSERT OR IGNORE INTO "server_battlenpc_groups" ("groupId", "poolId", "scriptName", "minLevel", "maxLevel", "respawnTime", "hp", "mp", "dropListId", "allegiance", "spawnType", "animationId", "actorState", "privateAreaName", "privateAreaLevel", "zoneId") VALUES
    (30131, 30118, 'gcu305_zombie_pikeman', 49, 50, 0, 2200, 0, 0, 0, 1, 0, 0, '', 0, 171),
    (30132, 30119, 'gcu305_zombie_mage',    49, 50, 0, 1800, 0, 0, 0, 1, 0, 0, '', 0, 171);

INSERT OR IGNORE INTO "server_battlenpc_spawn_locations" ("bnpcId", "customDisplayName", "groupId", "positionX", "positionY", "positionZ", "rotation") VALUES
    (3546, 'gcu305_zombie_pikeman', 30131, 1329.1, 256.1, -194.4, 3.14),
    (3547, 'gcu305_zombie_pikeman', 30131, 1321.5, 261.5, -170.2, 2.5),
    (3548, 'gcu305_zombie_mage',    30132, 1334.7, 261.7, -166.4, 3.0);
