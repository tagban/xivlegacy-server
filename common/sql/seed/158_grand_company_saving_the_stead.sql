-- Saving the Stead Instead (Gcl302), the Bloody Executioners' foray against
-- the kobolds (scripts/lua/quests/gcl/gcl302.lua). This adds:
--
-- * Hyllfyr, captain of the Bloody Executioners, aboard their ship the
--   Astalicia (Limsa Lominsa, zone 230), a second spawn of his Gcl103 class.
--   He stands in for the quest's giver, whom the client does not name.
-- * His restless men at the old kobold den north and east of Bloodshore
--   (Eastern La Noscea, zone 130), a beach pocket between the cliffs:
--   Fyrilskyf, who leads the foray, Albin, T'gizzoh and Denston.
-- * The kobolds, spawned by the duty (SimpleContentGcl30201).
--
-- Heights checked in the test client. The crew ship stripped in gamedata
-- (classPath '') and gets PopulaceStandard.
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
WHERE "id" IN (1001681, 1001682, 1001683, 1001684)
  AND ("classPath" = '' OR "classPath" IS NULL);

INSERT OR IGNORE INTO "server_spawn_locations"
    ("id", "actorClassId", "uniqueId", "zoneId", "privateAreaName", "privateAreaLevel",
     "positionX", "positionY", "positionZ", "rotation", "actorState", "animationId", "customDisplayName")
VALUES
    (27853, 1000215, 'gcl302_hyllfyr',   230, '', 0,  -775.50,  16.35,   386.20, -1.57, 0, 0, null),
    (27854, 1001681, 'gcl302_fyrilskyf', 130, '', 0,  1653.00,  -0.20,  -800.00,  3.14, 0, 0, null),
    (27855, 1001682, 'gcl302_albin',     130, '', 0,  1655.50,  -0.20,  -795.00,  2.80, 0, 0, null),
    (27856, 1001683, 'gcl302_tgizzoh',   130, '', 0,  1650.50,  -0.10,  -795.00, -2.80, 0, 0, null),
    (27857, 1001684, 'gcl302_denston',   130, '', 0,  1653.50,  -0.20,  -790.00,  3.14, 0, 0, null);

INSERT OR IGNORE INTO "server_battlenpc_pools" ("poolId", "actorClassId", "name", "genusId", "currentJob", "combatSkill", "combatDelay", "combatDmgMult", "aggroType", "immunity", "linkType", "spellListId", "skillListId") VALUES
    (30121, 2106622, 'Kobold Footman',   29, 0, 1, 4200, 1.0, 1, 0, 0, 0, 0),
    (30122, 2106625, 'Kobold Patrolman', 29, 0, 1, 4200, 1.0, 1, 0, 0, 0, 0);

-- spawnType 1 keeps them out of the open world: the duty spawns them.
INSERT OR IGNORE INTO "server_battlenpc_groups" ("groupId", "poolId", "scriptName", "minLevel", "maxLevel", "respawnTime", "hp", "mp", "dropListId", "allegiance", "spawnType", "animationId", "actorState", "privateAreaName", "privateAreaLevel", "zoneId") VALUES
    (30134, 30121, 'gcl302_kobold_footman',   25, 27, 0, 800, 0, 0, 0, 1, 0, 0, '', 0, 130),
    (30135, 30122, 'gcl302_kobold_patrolman', 25, 27, 0, 800, 0, 0, 0, 1, 0, 0, '', 0, 130);

INSERT OR IGNORE INTO "server_battlenpc_spawn_locations" ("bnpcId", "customDisplayName", "groupId", "positionX", "positionY", "positionZ", "rotation") VALUES
    (3555, 'gcl302_kobold_footman',   30134, 1652.0, -0.1, -826.0, 0.0),
    (3556, 'gcl302_kobold_footman',   30134, 1652.0, -0.2, -832.0, 0.3),
    (3557, 'gcl302_kobold_patrolman', 30135, 1655.0, -0.3, -840.0, -0.3),
    (3558, 'gcl302_kobold_patrolman', 30135, 1653.0,  0.0, -845.0, 0.0);
