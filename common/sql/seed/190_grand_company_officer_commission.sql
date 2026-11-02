-- The commission to officer (Gcl702, Gcg702, Gcu702), the Grand Companies'
-- gate from Chief Sergeant to Second Lieutenant
-- (scripts/lua/quests/gc/gc702.lua). Each officer sends you after a beast
-- that harries the company's patrols:
--
-- * The Maelstrom: a great buffalo north-east of Camp Bald Knoll, Western La
--   Noscea (zone 129), by the mouth of Mistbeard Cove. Nothing spawned it,
--   so this adds it (battle npc 3900, class 2100801, KujataHornedStandard),
--   a level 52 notorious monster that respawns in five minutes.
-- * The Twin Adder: Haughtpox Bloatbelly, North Shroud (152), and
-- * the Immortal Flames: the elder mosshorns, Western Thanalan (172). Both
--   are world monsters already (seed 101), so nothing is added for them.
--
-- The commission ends with a salute to the officer, so each officer gets one
-- emote condition, its company's salute ("emoteDefault1": Storm Salute 146,
-- Serpent Salute 147, Flame Salute 148). PopulaceCompanyOfficer ends a
-- salute no quest asked for.
--
-- Heights checked in the test client. Gc?702 follows Gc?701.
--
-- Idempotent: UPDATEs guarded, INSERTs OR IGNORE on id. No schema change.

UPDATE "gamedata_quests" SET "prerequisite" = 111428 WHERE "id" = 111434 AND "prerequisite" = 0;
UPDATE "gamedata_quests" SET "prerequisite" = 111628 WHERE "id" = 111634 AND "prerequisite" = 0;
UPDATE "gamedata_quests" SET "prerequisite" = 111828 WHERE "id" = 111834 AND "prerequisite" = 0;

UPDATE "gamedata_actor_class" SET "eventConditions" = '{"talkEventConditions":[{"unknown1":4,"unknown2":0,"conditionName":"talkDefault"}],"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}],"emoteEventConditions":[{"unknown1":4,"unknown2":0,"emoteId":146,"conditionName":"emoteDefault1"}]}'
    WHERE "id" = 1500199 AND "eventConditions" NOT LIKE '%emoteEventConditions%';
UPDATE "gamedata_actor_class" SET "eventConditions" = '{"talkEventConditions":[{"unknown1":4,"unknown2":0,"conditionName":"talkDefault"}],"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}],"emoteEventConditions":[{"unknown1":4,"unknown2":0,"emoteId":147,"conditionName":"emoteDefault1"}]}'
    WHERE "id" = 1500200 AND "eventConditions" NOT LIKE '%emoteEventConditions%';
UPDATE "gamedata_actor_class" SET "eventConditions" = '{"talkEventConditions":[{"unknown1":4,"unknown2":0,"conditionName":"talkDefault"}],"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}],"emoteEventConditions":[{"unknown1":4,"unknown2":0,"emoteId":148,"conditionName":"emoteDefault1"}]}'
    WHERE "id" = 1500198 AND "eventConditions" NOT LIKE '%emoteEventConditions%';

INSERT OR IGNORE INTO "server_battlenpc_pools" ("poolId", "actorClassId", "name", "genusId", "currentJob", "combatSkill", "combatDelay", "combatDmgMult", "aggroType", "immunity", "linkType", "spellListId", "skillListId") VALUES
    (30200, 2100801, 'Great Buffalo', 8, 0, 1, 4500, 1.5, 1, 0, 0, 0, 0);

INSERT OR IGNORE INTO "server_battlenpc_groups" ("groupId", "poolId", "scriptName", "minLevel", "maxLevel", "respawnTime", "hp", "mp", "dropListId", "allegiance", "spawnType", "animationId", "actorState", "privateAreaName", "privateAreaLevel", "zoneId") VALUES
    (30300, 30200, 'gcl702_great_buffalo', 52, 52, 300, 9000, 0, 0, 0, 0, 0, 0, '', 0, 129);

INSERT OR IGNORE INTO "server_battlenpc_spawn_locations" ("bnpcId", "customDisplayName", "groupId", "positionX", "positionY", "positionZ", "rotation") VALUES
    (3900, 'gcl702_great_buffalo', 30300, -1712.0, 50.5, -1484.0, 2.4);
