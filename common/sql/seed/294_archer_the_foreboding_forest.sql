-- Arc300 The Foreboding Forest (scripts/lua/quests/arc/arc300.lua): the
-- Archers' Guild's rank 30 quest, which had no script.
--
-- 1. Keelty appears only in the quest's cutscenes (her classes ship
--    stripped), so each meeting is a push circle where its scene starts,
--    as in Arc200. The stripped classes 1090510-1090514 (classPath '', no
--    spawn, no other reference) become those circles, disabled until the
--    quest turns each on:
--      1090510 the guild's back room, Quiver's Hold (processEvent007)
--      1090511 the gate of Owl's Nest (arc30010)
--      1090512 where Keelty finds you in Owl's Nest (arc30020/025)
--      1090513 the North Shroud field near the Coerthas border (arc30025,
--              then content Arc30001)
--      1090514 where Keelty asks for the Echo (arc30040)
--    Positions come from the scenes' actor tracks, heights from the
--    client's ground mesh. 1090513 sits about 13 yalms off Arc200's Ixal
--    circle (1090504).
-- 2. The fight (content Arc30001): a bandit archer (class 2180128) and a
--    thunder mage (class 2180131), both stripped of a classPath, which a
--    spawned battle npc needs. They get PirateStandard, the hostile human
--    class their unstripped neighbours 2180201-2180219 ship with; the
--    FighterAlly classes draw an ally's green name.
--
-- Idempotent: UPDATEs guarded on the value they fix, INSERTs OR IGNORE on id.

UPDATE "gamedata_actor_class" SET
    "classPath" = '/Chara/Npc/Populace/PopulaceStandard',
    "propertyFlags" = 1,
    "eventConditions" = '{
  "pushWithCircleEventConditions": [
    {
      "isEnabled": "false",
      "radius": "4.0",
      "outwards": "false",
      "silent": "false",
      "conditionName": "pushDefault"
    }
  ]
}'
WHERE "id" IN (1090510, 1090511, 1090512, 1090513, 1090514) AND ("classPath" = '' OR "classPath" IS NULL);

INSERT OR IGNORE INTO "server_spawn_locations"
    ("id", "actorClassId", "uniqueId", "zoneId", "privateAreaName", "privateAreaLevel",
     "positionX", "positionY", "positionZ", "rotation", "actorState", "animationId", "customDisplayName")
VALUES
    (29028, 1090510, 'arc300_guild_back_room_trigger', 206, '', 0, 237.7, 12.0, -1278.0, 0.00, 0, 0, null),
    (29029, 1090511, 'arc300_owls_nest_gate_trigger', 145, '', 0, 2542.5, 174.2, 1273.6, 0.00, 0, 0, null),
    (29030, 1090512, 'arc300_owls_nest_keelty_trigger', 145, '', 0, 2568.6, 175.46, 1315.0, 0.00, 0, 0, null),
    (29031, 1090513, 'arc300_border_field_trigger', 152, '', 0, -1563.0, 20.03, -1889.0, 0.00, 0, 0, null),
    (29032, 1090514, 'arc300_keelty_echo_trigger', 152, '', 0, -1586.3, 20.67, -1883.9, 0.00, 0, 0, null);

UPDATE "gamedata_actor_class" SET
    "classPath" = '/Chara/Npc/Monster/Pirate/PirateStandard'
WHERE "id" IN (2180128, 2180131) AND ("classPath" = '' OR "classPath" IS NULL);

INSERT OR IGNORE INTO "server_battlenpc_pools" ("poolId", "actorClassId", "name", "genusId", "currentJob", "combatSkill", "combatDelay", "combatDmgMult", "aggroType", "immunity", "linkType", "spellListId", "skillListId") VALUES
    (30221, 2180128, 'arc300_bandit_archer', 29, 7, 1, 4500, 0.25, 0, 0, 0, 0, 0),
    (30222, 2180131, 'arc300_thunder_mage', 29, 22, 1, 5000, 0.25, 0, 0, 0, 0, 0);

INSERT OR IGNORE INTO "server_battlenpc_groups" ("groupId", "poolId", "scriptName", "minLevel", "maxLevel", "respawnTime", "hp", "mp", "dropListId", "allegiance", "spawnType", "animationId", "actorState", "privateAreaName", "privateAreaLevel", "zoneId") VALUES
    (30321, 30221, 'arc300_bandit_archer', 28, 28, 0, 450, 0, 0, 0, 16, 0, 0, '', 0, 152),
    (30322, 30222, 'arc300_thunder_mage', 28, 28, 0, 400, 0, 0, 0, 16, 0, 0, '', 0, 152);

INSERT OR IGNORE INTO "server_battlenpc_spawn_locations" ("bnpcId", "customDisplayName", "groupId", "positionX", "positionY", "positionZ", "rotation") VALUES
    (3944, 'arc300_bandit_archer', 30321, -1591.0, 20.88, -1915.0, 0.0),
    (3945, 'arc300_thunder_mage', 30322, -1582.0, 20.99, -1914.0, 0.0);
