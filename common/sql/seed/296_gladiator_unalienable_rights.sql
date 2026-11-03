-- Gla300 Unalienable Rights (scripts/lua/quests/gla/gla300.lua): the
-- Gladiators' Guild's rank 30 quest, which had no script.
--
-- 1. The quest ships with no prerequisite; it gets Gla200 (110080), as
--    Arc300, Lnc300 and Pgl300 have theirs.
-- 2. Yoyobina's Gridania body (1001076: PopulaceStandard, talkDefault, no
--    spawn) stands where the quest needs him away from the Coliseum: in the
--    Wailing Barracks courtyard after the spar (processEvent055, beside the
--    gla30040 track), and in the past Coliseum (PrivateAreaMasterPast 5,
--    shared with man0u1) a few yalms from where the Echo sets you down
--    (gla30080).
-- 3. The spar (content Gla30001): J'moldva's battle class 2289009 ships
--    stripped of a classPath, which a spawned battle npc needs. It gets
--    PirateStandard, the hostile human class; the FighterAlly classes draw
--    an ally's green name. Her appearance row already matches the ENPC.
--
-- Idempotent: UPDATEs guarded on the value they fix, INSERTs OR IGNORE on id.

UPDATE "gamedata_quests" SET "prerequisite" = 110080
WHERE "id" = 110081 AND "prerequisite" = 0;

INSERT OR IGNORE INTO "server_spawn_locations"
    ("id", "actorClassId", "uniqueId", "zoneId", "privateAreaName", "privateAreaLevel",
     "positionX", "positionY", "positionZ", "rotation", "actorState", "animationId", "customDisplayName")
VALUES
    (29035, 1001076, 'gla300_yoyobina_barracks', 206, '', 0, 187.0, 27.5, -1583.5, -1.57, 0, 0, null),
    (29036, 1001076, 'gla300_yoyobina_past', 209, 'PrivateAreaMasterPast', 5, -189.0, 195.0, 182.0, 0.9, 0, 0, null);

UPDATE "gamedata_actor_class" SET
    "classPath" = '/Chara/Npc/Monster/Pirate/PirateStandard'
WHERE "id" = 2289009 AND ("classPath" = '' OR "classPath" IS NULL);

INSERT OR IGNORE INTO "server_battlenpc_pools" ("poolId", "actorClassId", "name", "genusId", "currentJob", "combatSkill", "combatDelay", "combatDmgMult", "aggroType", "immunity", "linkType", "spellListId", "skillListId") VALUES
    (30226, 2289009, 'gla300_jmoldva', 29, 8, 1, 4500, 0.45, 0, 0, 0, 0, 0);

INSERT OR IGNORE INTO "server_battlenpc_groups" ("groupId", "poolId", "scriptName", "minLevel", "maxLevel", "respawnTime", "hp", "mp", "dropListId", "allegiance", "spawnType", "animationId", "actorState", "privateAreaName", "privateAreaLevel", "zoneId") VALUES
    (30326, 30226, 'gla300_jmoldva', 30, 30, 0, 1400, 0, 0, 0, 16, 0, 0, '', 0, 206);

INSERT OR IGNORE INTO "server_battlenpc_spawn_locations" ("bnpcId", "customDisplayName", "groupId", "positionX", "positionY", "positionZ", "rotation") VALUES
    (3949, 'gla300_jmoldva', 30326, 195.0, 27.9, -1581.0, -1.57);
