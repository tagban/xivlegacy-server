-- Lord Errant (Man308, the shared level 38 story): your Path companion's
-- errand to the Amalj'aa of Paglth'an (scripts/lua/quests/man/man308.lua).
-- This adds:
--
-- * The quest's place in the story: it follows Forever Taken.
-- * Four walk-in triggers: the Gold Court in Ul'dah, where your companion
--   proposes the errand, and three at Paglth'an in Southern Thanalan (zone
--   174): the approach where the sylphs wait, the gates where the guard
--   spots you, and the way out of the cell to Ifrit's summoning. The
--   Paglth'an spots are the quest's own journal map markers (11001702,
--   11001705, 11001708), read off its map at 1 yalm a pixel. The last two
--   lie in a narrow cave under the cliff; the cell, the trigger and the
--   fight sit on its floor (y 308-313, heights checked in the test client).
--   The Gold Court has no marker; its trigger stands in the hall the Company
--   warp lands in.
-- * The two prisoners in the cell (markers 11001706-11001707), whose class
--   rows shipped stripped.
-- * The summoning (SimpleContentMan30801): the three tempered captives, given
--   the pirates' class path so they can fight, and five Amalj'aa from the
--   zone family's pools (two lancers, a drubber, a bowyer and a divinator),
--   around the quest's level 38.
--
-- Idempotent: UPDATEs guarded, INSERTs OR IGNORE on id. No schema change.

UPDATE "gamedata_quests" SET "prerequisite" = 110016 WHERE "id" = 110017 AND "prerequisite" = 0;

-- Four walk-in triggers, borrowing stripped classes (classPath '', no spawn,
-- no other reference). Their push circles stay off until the quest turns
-- them on.
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
WHERE "id" IN (1090363, 1090364, 1090365, 1090366) AND ("classPath" = '' OR "classPath" IS NULL);

-- The prisoners talk like Tataru (seed 112's townsfolk row).
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
WHERE "id" IN (1001390, 1001391) AND ("classPath" = '' OR "classPath" IS NULL);

-- The tempered captives look like players (appearance base 1); the pirates
-- are the hostile class built for that.
UPDATE "gamedata_actor_class" SET "classPath" = '/Chara/Npc/Monster/Pirate/PirateStandard'
WHERE "id" IN (2289001, 2289002, 2289003) AND ("classPath" = '' OR "classPath" IS NULL);

INSERT OR IGNORE INTO "server_spawn_locations"
    ("id", "actorClassId", "uniqueId", "zoneId", "privateAreaName", "privateAreaLevel",
     "positionX", "positionY", "positionZ", "rotation", "actorState", "animationId", "customDisplayName")
VALUES
    (27886, 1090363, 'man308_gold_court', 209, '', 0,  -141.60, 198.00,  160.00, 0.00, 0, 0, null),
    (27887, 1090364, 'man308_paglthan_approach', 174, '', 0,  1141.00, 317.00,  839.00, 0.00, 0, 0, null),
    (27888, 1090365, 'man308_paglthan_gates', 174, '', 0,  992.00, 311.80,  967.00, 0.00, 0, 0, null),
    (27889, 1090366, 'man308_paglthan_clearing', 174, '', 0,  993.30, 310.00,  976.80, 0.00, 0, 0, null),
    (27890, 1001390, 'man308_cloudy_eyed_prisoner', 174, '', 0,  993.30, 312.00,  988.80, 3.14, 0, 0, null),
    (27891, 1001391, 'man308_emotionless_prisoner', 174, '', 0,  995.70, 308.40,  990.30, 3.14, 0, 0, null);

-- The summoning: three tempered captives and five Amalj'aa.
INSERT OR IGNORE INTO "server_battlenpc_pools" ("poolId", "actorClassId", "name", "genusId", "currentJob", "combatSkill", "combatDelay", "combatDmgMult", "aggroType", "immunity", "linkType", "spellListId", "skillListId") VALUES
    (30129, 2289001, 'tempered_captive_1', 3, 0, 1, 4200, 1, 1, 0, 0, 0, 0),
    (30130, 2289002, 'tempered_captive_2', 3, 0, 1, 4200, 1, 1, 0, 0, 0, 0),
    (30131, 2289003, 'tempered_captive_3', 3, 0, 1, 4200, 1, 1, 0, 0, 0, 0);

INSERT OR IGNORE INTO "server_battlenpc_groups" ("groupId", "poolId", "scriptName", "minLevel", "maxLevel", "respawnTime", "hp", "mp", "dropListId", "allegiance", "spawnType", "animationId", "actorState", "privateAreaName", "privateAreaLevel", "zoneId") VALUES
    (30142, 30129, 'paglthan_captive',   37, 38, 0, 700, 0, 0, 0, 1, 0, 0, '', 0, 174),
    (30143, 30130, 'paglthan_captive',   37, 38, 0, 700, 0, 0, 0, 1, 0, 0, '', 0, 174),
    (30144, 30131, 'paglthan_captive',   37, 38, 0, 700, 0, 0, 0, 1, 0, 0, '', 0, 174),
    (30145, 10058, 'paglthan_amaljaa',   37, 38, 0, 900, 0, 0, 0, 1, 0, 0, '', 0, 174),
    (30146, 10061, 'paglthan_amaljaa',   37, 38, 0, 900, 0, 0, 0, 1, 0, 0, '', 0, 174),
    (30147, 10060, 'paglthan_amaljaa',   37, 38, 0, 900, 0, 0, 0, 1, 0, 0, '', 0, 174),
    (30148, 10059, 'paglthan_amaljaa',   37, 38, 0, 900, 0, 0, 0, 1, 0, 0, '', 0, 174);

INSERT OR IGNORE INTO "server_battlenpc_spawn_locations" ("bnpcId", "customDisplayName", "groupId", "positionX", "positionY", "positionZ", "rotation") VALUES
    (3584, 'tempered_captive', 30142,  991.3, 311.9, 965.2, 0.00),
    (3585, 'tempered_captive', 30143,  995.5, 312.7, 962.2, 0.00),
    (3586, 'tempered_captive', 30144,  991.3, 312.1, 961.2, 0.00),
    (3587, 'paglthan_amaljaa', 30145,  995.5, 312.4, 956.2, 0.00),
    (3588, 'paglthan_amaljaa', 30145,  991.3, 311.7, 954.2, 0.00),
    (3589, 'paglthan_amaljaa', 30146,  993.1, 312.0, 956.9, 0.00),
    (3590, 'paglthan_amaljaa', 30147,  993.0, 311.4, 951.6, 0.00),
    (3591, 'paglthan_amaljaa', 30148,  987.3, 311.8, 952.8, 0.00);
