-- Pgl200 The House Always Wins (scripts/lua/quests/pgl/pgl200.lua): the
-- Pugilists' Guild's two duties, which the ported script skipped.
--
-- 1. Esperaunce's dropped gil, in the quest's Eshtaime's Lapidaries private
--    area (zone 209, PrivateAreaMasterPast 5). Five "???" glints (the
--    unused sparkle classes 1080014-16, 1080019-20, model 20997) lie on the shop
--    floor around him; each is picked up once.
-- 2. The bloodsands match for Lady Lewena: content Pgl20002 in the Coliseum
--    (the man0u1 arena spot), against a veteran gladiator who, unlike
--    man0u1's tourney gladiator, can be beaten.
--
-- Esperaunce and his two companions (1000952-1000954) and the glints
-- shipped with no event conditions at all, so the client had nothing to
-- talk to; they get the populace talk + notice pair.
--
-- Idempotent: INSERT OR IGNORE on ids, UPDATEs guarded on the value they fix.

UPDATE "gamedata_actor_class" SET
    "classPath" = '/Chara/Npc/Populace/PopulaceStandard', "propertyFlags" = 19
WHERE "id" IN (1080014, 1080015, 1080016, 1080019, 1080020) AND "classPath" = '';

UPDATE "gamedata_actor_class" SET "eventConditions" =
    '{"talkEventConditions":[{"unknown1":4,"unknown2":0,"conditionName":"talkDefault"}],"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}]}'
WHERE "id" IN (1000952, 1000953, 1000954, 1080014, 1080015, 1080016, 1080019, 1080020)
  AND ("eventConditions" IS NULL OR "eventConditions" = '');

INSERT OR IGNORE INTO "server_spawn_locations" ("id", "actorClassId", "uniqueId", "zoneId", "privateAreaName", "privateAreaLevel", "positionX", "positionY", "positionZ", "rotation", "actorState", "animationId", "customDisplayName") VALUES
    (29010, 1080014, 'pgl200_coin_1', 209, 'PrivateAreaMasterPast', 5, -122.4, 200.2, 270.6, 0.0, 0, 0, ''),
    (29011, 1080015, 'pgl200_coin_2', 209, 'PrivateAreaMasterPast', 5, -126.3, 200.2, 270.2, 0.0, 0, 0, ''),
    (29012, 1080016, 'pgl200_coin_3', 209, 'PrivateAreaMasterPast', 5, -121.2, 200.2, 266.4, 0.0, 0, 0, ''),
    (29013, 1080019, 'pgl200_coin_4', 209, 'PrivateAreaMasterPast', 5, -122.6, 200.2, 267.2, 0.0, 0, 0, ''),
    (29014, 1080020, 'pgl200_coin_5', 209, 'PrivateAreaMasterPast', 5, -125.4, 200.2, 267.4, 0.0, 0, 0, '');

-- The veteran: the Coliseum gladiator class (2280157, seed 096), its own
-- pool so the duty can tune level and HP apart from man0u1.
INSERT OR IGNORE INTO "server_battlenpc_pools" ("poolId", "actorClassId", "name", "genusId", "currentJob", "combatSkill", "combatDelay", "combatDmgMult", "aggroType", "immunity", "linkType", "spellListId", "skillListId") VALUES
    (30211, 2280157, 'pgl200_coliseum_veteran', 29, 3, 1, 4200, 0.7, 0, 0, 0, 0, 0);

INSERT OR IGNORE INTO "server_battlenpc_groups" ("groupId", "poolId", "scriptName", "minLevel", "maxLevel", "respawnTime", "hp", "mp", "dropListId", "allegiance", "spawnType", "animationId", "actorState", "privateAreaName", "privateAreaLevel", "zoneId") VALUES
    (30311, 30211, 'pgl200_coliseum_veteran', 22, 22, 0, 900, 0, 0, 0, 16, 0, 0, '', 0, 209);

INSERT OR IGNORE INTO "server_battlenpc_spawn_locations" ("bnpcId", "customDisplayName", "groupId", "positionX", "positionY", "positionZ", "rotation") VALUES
    (3923, 'pgl200_coliseum_veteran', 30311, -205.4, 192.0, 150.9, 0.0);

-- The past private areas' exit (1290002) is a pair of big circles around
-- the area, "caution" at 50 yalms and "exit" at 60, meant to fire as the
-- player walks OUT. They shipped inwards, so the client fired both as soon
-- as the player arrived and the area threw them straight back out (Pgl200
-- looped in and out of Eshtaime's Lapidaries every 3 seconds).
UPDATE "gamedata_actor_class" SET "eventConditions" = json_set("eventConditions",
    '$.pushWithCircleEventConditions[0].outwards', json('true'),
    '$.pushWithCircleEventConditions[1].outwards', json('true'))
WHERE "id" = 1290002 AND json_extract("eventConditions", '$.pushWithCircleEventConditions[0].outwards') = 0;
