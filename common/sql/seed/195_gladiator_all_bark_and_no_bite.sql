-- Gla200 All Bark and No Bite (scripts/lua/quests/gla/gla200.lua): the
-- Gladiators' Guild's welcome, which had no script.
--
-- 1. The doors at the back of the guild hall: Lulutsu sends you through
--    the doors to the sands. The stripped class 1090500 (classPath '', no
--    spawn, no other reference) becomes a small push circle where Yoyobina
--    keeps the doors, disabled until the quest turns it on. It is kept
--    small so the counter, where you take the quest, stays outside it.
-- 2. The preliminary bout (content Gla20001, on the man0u1/Pgl200 arena
--    spot): an Ala Mhigan challenger (class 2289006, the "Ala Mhigan
--    challenger" name), weak by design. Class 2289006 also ships stripped
--    (classPath ''), which crashes the client when it spawns; it gets the
--    fighter class the Pgl200 veteran uses.
--
-- Idempotent: UPDATE guarded on the value it fixes, INSERTs OR IGNORE on id.

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
WHERE "id" = 1090500 AND ("classPath" = '' OR "classPath" IS NULL);

INSERT OR IGNORE INTO "server_spawn_locations"
    ("id", "actorClassId", "uniqueId", "zoneId", "privateAreaName", "privateAreaLevel",
     "positionX", "positionY", "positionZ", "rotation", "actorState", "animationId", "customDisplayName")
VALUES
    (29015, 1090500, 'gla200_arena_doors_trigger', 209, '', 0, -184.10, 195.00, 180.70, 0.00, 0, 0, null);

UPDATE "gamedata_actor_class" SET
    "classPath" = '/Chara/Npc/Monster/Fighter/FighterAllyOpeningAttacker'
WHERE "id" = 2289006 AND ("classPath" = '' OR "classPath" IS NULL);

INSERT OR IGNORE INTO "server_battlenpc_pools" ("poolId", "actorClassId", "name", "genusId", "currentJob", "combatSkill", "combatDelay", "combatDmgMult", "aggroType", "immunity", "linkType", "spellListId", "skillListId") VALUES
    (30212, 2289006, 'gla200_ala_mhigan_challenger', 29, 3, 1, 4200, 0.5, 0, 0, 0, 0, 0);

INSERT OR IGNORE INTO "server_battlenpc_groups" ("groupId", "poolId", "scriptName", "minLevel", "maxLevel", "respawnTime", "hp", "mp", "dropListId", "allegiance", "spawnType", "animationId", "actorState", "privateAreaName", "privateAreaLevel", "zoneId") VALUES
    (30312, 30212, 'gla200_ala_mhigan_challenger', 18, 18, 0, 700, 0, 0, 0, 16, 0, 0, '', 0, 209);

INSERT OR IGNORE INTO "server_battlenpc_spawn_locations" ("bnpcId", "customDisplayName", "groupId", "positionX", "positionY", "positionZ", "rotation") VALUES
    (3924, 'gla200_ala_mhigan_challenger', 30312, -205.4, 192.0, 150.9, 0.0);
