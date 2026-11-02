-- The promotion to Sergeant (Gcl701, Gcg701, Gcu701), the Grand Companies'
-- gate from Corporal to Sergeant Third Class
-- (scripts/lua/quests/gc/gc701.lua). Each officer sends you to a commander
-- in the field who runs a War Merit duty against a beastman camp:
--
-- * The Maelstrom: Storm Sergeant Alain Brooks (1001833) east of the kobold
--   encampment, Upper La Noscea (zone 135).
-- * The Twin Adder: First Commander Vorsaile Heuloix (1001835) on the
--   outskirts of the Ixali clearing, North Shroud (152).
-- * The Immortal Flames: First Commander Ashdale (1001834) by the Amalj'aa
--   altar, Eastern Thanalan (171).
--
-- The three commanders had no class path, so they become PopulaceStandard
-- with a talk condition, as seed 152 does for its NPCs. The duty spawns
-- seven beastmen per camp (SimpleContentGc?70101); spawnType 1 keeps them out
-- of the open world. Four of the lowest rank, two of the middle and one
-- leader: 4 x 100 + 2 x 150 + 300 = 1,000 War Merit.
--
-- The kobolds' heights were checked in the test client. The Ixal stand on
-- the stock galago spots west of Treespeak and the Amalj'aa on the stock
-- Amalj'aa spots by the altar (seed 101), whose heights render true; Ashdale
-- waits in the gully west of the camp.
--
-- Idempotent: UPDATEs guarded, INSERTs OR IGNORE on id. No schema change.

UPDATE "gamedata_actor_class" SET
    "classPath" = '/Chara/Npc/Populace/PopulaceStandard',
    "propertyFlags" = 19,
    "eventConditions" = '{"talkEventConditions":[{"unknown1":4,"unknown2":0,"conditionName":"talkDefault"}],"noticeEventConditions":[{"unknown1":0,"unknown2":1,"conditionName":"noticeEvent"}]}'
WHERE "id" IN (1001833, 1001834, 1001835) AND ("classPath" = '' OR "classPath" IS NULL);

INSERT OR IGNORE INTO "server_spawn_locations"
    ("id", "actorClassId", "uniqueId", "zoneId", "privateAreaName", "privateAreaLevel",
     "positionX", "positionY", "positionZ", "rotation", "actorState", "animationId", "customDisplayName")
VALUES
    (29000, 1001833, 'gc701_alain',    135, '', 0,  -655.00,  66.30, -1650.00, -1.60, 0, 0, null),
    (29001, 1001835, 'gc701_vorsaile', 152, '', 0,  -1221.56,  35.12, -2244.03, -1.57, 0, 0, null),
    (29002, 1001834, 'gc701_ashdale',  171, '', 0,   1414.00, 247.84,   253.64,  1.57, 0, 0, null);

INSERT OR IGNORE INTO "server_battlenpc_pools" ("poolId", "actorClassId", "name", "genusId", "currentJob", "combatSkill", "combatDelay", "combatDmgMult", "aggroType", "immunity", "linkType", "spellListId", "skillListId") VALUES
    (30201, 2206606, 'Kobold Cragsman',         29, 0, 1, 4200, 1.0, 1, 0, 0, 0, 0),
    (30202, 2206607, 'Kobold Roundsman',        29, 0, 1, 4200, 1.0, 1, 0, 0, 0, 0),
    (30203, 2206608, 'Kobold Bedesman',         29, 0, 1, 4200, 1.0, 1, 0, 0, 0, 0),
    (30204, 2206409, 'Ixali Limbcutter',        24, 0, 1, 4200, 1.0, 1, 0, 0, 0, 0),
    (30205, 2206410, 'Ixali Soilseer',          24, 0, 1, 4200, 1.0, 1, 0, 0, 0, 0),
    (30206, 2206411, 'Ixali Cloudwalker',       24, 0, 1, 4200, 1.0, 1, 0, 0, 0, 0),
    (30207, 2206525, 'Amalj''aa Pennoncier',     23, 0, 1, 4200, 1.0, 1, 0, 0, 0, 0),
    (30208, 2206526, 'Amalj''aa Captain',        23, 0, 1, 4200, 1.0, 1, 0, 0, 0, 0),
    (30209, 2206527, 'Amalj''aa High Divinator', 23, 0, 1, 4200, 1.0, 1, 0, 0, 0, 0);

-- spawnType 1 keeps them out of the open world: the duty spawns them.
INSERT OR IGNORE INTO "server_battlenpc_groups" ("groupId", "poolId", "scriptName", "minLevel", "maxLevel", "respawnTime", "hp", "mp", "dropListId", "allegiance", "spawnType", "animationId", "actorState", "privateAreaName", "privateAreaLevel", "zoneId") VALUES
    (30301, 30201, 'gcl701_cragsman',         44, 45, 0, 1800, 0, 0, 0, 1, 0, 0, '', 0, 135),
    (30302, 30202, 'gcl701_roundsman',        46, 47, 0, 2200, 0, 0, 0, 1, 0, 0, '', 0, 135),
    (30303, 30203, 'gcl701_bedesman',         48, 48, 0, 3000, 0, 0, 0, 1, 0, 0, '', 0, 135),
    (30304, 30204, 'gcg701_limbcutter',       44, 45, 0, 1800, 0, 0, 0, 1, 0, 0, '', 0, 152),
    (30305, 30205, 'gcg701_soilseer',         46, 47, 0, 2200, 0, 0, 0, 1, 0, 0, '', 0, 152),
    (30306, 30206, 'gcg701_cloudwalker',      48, 48, 0, 3000, 0, 0, 0, 1, 0, 0, '', 0, 152),
    (30307, 30207, 'gcu701_pennoncier',       44, 45, 0, 1800, 0, 0, 0, 1, 0, 0, '', 0, 171),
    (30308, 30208, 'gcu701_captain',          46, 47, 0, 2200, 0, 0, 0, 1, 0, 0, '', 0, 171),
    (30309, 30209, 'gcu701_high_divinator',   48, 48, 0, 3000, 0, 0, 0, 1, 0, 0, '', 0, 171);

INSERT OR IGNORE INTO "server_battlenpc_spawn_locations" ("bnpcId", "customDisplayName", "groupId", "positionX", "positionY", "positionZ", "rotation") VALUES
    (3901, 'gcl701_cragsman',       30301, -668.0, 63.5, -1636.0,  1.0),
    (3902, 'gcl701_cragsman',       30301, -678.0, 64.5, -1628.0,  1.6),
    (3903, 'gcl701_cragsman',       30301, -692.0, 66.3, -1636.0,  1.2),
    (3904, 'gcl701_cragsman',       30301, -672.0, 68.1, -1666.0,  0.4),
    (3905, 'gcl701_roundsman',      30302, -682.0, 69.0, -1660.0,  0.9),
    (3906, 'gcl701_roundsman',      30302, -688.0, 69.2, -1650.0,  1.4),
    (3907, 'gcl701_bedesman',       30303, -696.0, 70.6, -1660.0,  1.2),
    (3908, 'gcg701_limbcutter',     30304, -1232.4, 34.9, -2237.2,  1.3),
    (3909, 'gcg701_limbcutter',     30304, -1251.4, 34.6, -2226.4,  0.1),
    (3910, 'gcg701_limbcutter',     30304, -1255.6, 34.6, -2239.8,  1.6),
    (3911, 'gcg701_limbcutter',     30304, -1227.2, 35.1, -2259.0,  1.3),
    (3912, 'gcg701_soilseer',       30305, -1234.8, 31.9, -2268.1,  1.4),
    (3913, 'gcg701_soilseer',       30305, -1254.3, 31.4, -2269.3,  2.2),
    (3914, 'gcg701_cloudwalker',    30306, -1275.0, 31.1, -2263.0, -0.6),
    (3915, 'gcu701_pennoncier',     30307, 1469.0, 257.2, 259.1,  0.9),
    (3916, 'gcu701_pennoncier',     30307, 1452.0, 257.5, 243.3, -0.5),
    (3917, 'gcu701_pennoncier',     30307, 1477.4, 257.2, 246.7, -0.8),
    (3918, 'gcu701_pennoncier',     30307, 1478.0, 257.1, 254.9, -2.4),
    (3919, 'gcu701_captain',        30308, 1487.4, 257.0, 259.5, -2.3),
    (3920, 'gcu701_captain',        30308, 1500.5, 256.9, 264.8,  1.2),
    (3921, 'gcu701_high_divinator', 30309, 1515.6, 256.7, 266.9,  0.1);
