-- Pgl300 Here There Be Pirates (scripts/lua/quests/pgl/pgl300.lua): the
-- Pugilists' Guild's rank 30 quest, which had no script.
--
-- 1. Its gamedata row has no prerequisite, so Gagaruna would offer it
--    before Pgl200; it gets 110060, as Arc300 and Lnc300 have theirs.
-- 2. U'mallibo and Hurrey ship stripped (cutscene only), so two stripped
--    trigger classes (classPath '', no spawn, no other reference) become
--    push circles, disabled until the quest turns each on:
--      1090515 the Mizzenmast's inn counter, zone 133 (pgl30030)
--      1090516 the Sailors Ward side of the Market Wards door, zone 230:
--              the Misery's gangway (content Pgl30001)
--    Positions from the scenes' actor tracks (Limsa cut coordinates are
--    server coordinates less (-448, 0, +193.7)).
-- 3. The hold has no map of its own; the content runs in the Rhotano Sea
--    ship's hold (zone 192). Its chest and door are two unused sparkle
--    classes (1080017-1080018, model 20997, like Pgl200's coins) given the
--    populace talk pair; the content spawns them.
-- 4. Three Kraken deckhands (classes 2280213-2280215, PirateStandard since
--    seed 106, no pool until now) wait in the hold, level 25.
--
-- Idempotent: UPDATEs guarded on the value they fix, INSERTs OR IGNORE on id.

UPDATE "gamedata_quests" SET "prerequisite" = 110060
WHERE "id" = 110061 AND "prerequisite" = 0;

UPDATE "gamedata_actor_class" SET
    "classPath" = '/Chara/Npc/Populace/PopulaceStandard',
    "propertyFlags" = 1,
    "eventConditions" = '{
  "pushWithCircleEventConditions": [
    {
      "isEnabled": "false",
      "radius": "3.0",
      "outwards": "false",
      "silent": "false",
      "conditionName": "pushDefault"
    }
  ]
}'
WHERE "id" IN (1090515, 1090516) AND ("classPath" = '' OR "classPath" IS NULL);

INSERT OR IGNORE INTO "server_spawn_locations"
    ("id", "actorClassId", "uniqueId", "zoneId", "privateAreaName", "privateAreaLevel",
     "positionX", "positionY", "positionZ", "rotation", "actorState", "animationId", "customDisplayName")
VALUES
    (29033, 1090515, 'pgl300_mizzenmast_trigger', 133, '', 0, -437.4, 40.0, 207.95, 0.00, 0, 0, null),
    (29034, 1090516, 'pgl300_misery_gangway_trigger', 230, '', 0, -413.0, 41.1, 437.5, 0.00, 0, 0, null);

UPDATE "gamedata_actor_class" SET
    "classPath" = '/Chara/Npc/Populace/PopulaceStandard', "propertyFlags" = 19,
    "eventConditions" = '{"talkEventConditions":[{"unknown1":4,"unknown2":0,"conditionName":"talkDefault"}],"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}]}'
WHERE "id" IN (1080017, 1080018) AND ("classPath" = '' OR "classPath" IS NULL);

INSERT OR IGNORE INTO "server_battlenpc_pools" ("poolId", "actorClassId", "name", "genusId", "currentJob", "combatSkill", "combatDelay", "combatDmgMult", "aggroType", "immunity", "linkType", "spellListId", "skillListId") VALUES
    (30223, 2280213, 'pgl300_kraken_deckhand_1', 29, 3, 1, 4800, 0.6, 0, 0, 0, 0, 0),
    (30224, 2280214, 'pgl300_kraken_deckhand_2', 29, 3, 1, 4800, 0.6, 0, 0, 0, 0, 0),
    (30225, 2280215, 'pgl300_kraken_deckhand_3', 29, 3, 1, 4800, 0.6, 0, 0, 0, 0, 0);

INSERT OR IGNORE INTO "server_battlenpc_groups" ("groupId", "poolId", "scriptName", "minLevel", "maxLevel", "respawnTime", "hp", "mp", "dropListId", "allegiance", "spawnType", "animationId", "actorState", "privateAreaName", "privateAreaLevel", "zoneId") VALUES
    (30323, 30223, 'pgl300_kraken_deckhand', 25, 25, 0, 650, 0, 0, 0, 16, 0, 0, '', 0, 192),
    (30324, 30224, 'pgl300_kraken_deckhand', 25, 25, 0, 650, 0, 0, 0, 16, 0, 0, '', 0, 192),
    (30325, 30225, 'pgl300_kraken_deckhand', 25, 25, 0, 650, 0, 0, 0, 16, 0, 0, '', 0, 192);

INSERT OR IGNORE INTO "server_battlenpc_spawn_locations" ("bnpcId", "customDisplayName", "groupId", "positionX", "positionY", "positionZ", "rotation") VALUES
    (3946, 'pgl300_kraken_deckhand', 30323, 1818.5, -61.65, 1806.8, 0.0),
    (3947, 'pgl300_kraken_deckhand', 30324, 1823.1, -59.39, 1799.1, 0.0),
    (3948, 'pgl300_kraken_deckhand', 30325, 1824.9, -59.39, 1800.0, 0.0);
