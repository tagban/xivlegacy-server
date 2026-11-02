-- Eternal Recurrence (Gcg301), the Twin Adder's errand for the
-- Leatherworkers' Guild (scripts/lua/quests/gcg/gcg301.lua). Dyrstbrod
-- already stands in Gridania. This adds the hungry dreadwolves that prowl
-- the old battlefield on the south shore of Fallgourd Lake (North Shroud,
-- zone 152), west of Camp Emerald Moss.
--
-- Heights taken from the stock spawns on that shore and checked in the
-- test client.
--
-- Idempotent: INSERTs OR IGNORE on id. No schema change.

INSERT OR IGNORE INTO "server_battlenpc_pools" ("poolId", "actorClassId", "name", "genusId", "currentJob", "combatSkill", "combatDelay", "combatDmgMult", "aggroType", "immunity", "linkType", "spellListId", "skillListId") VALUES
    (30125, 2201412, 'Hungry Dreadwolf', 3, 0, 1, 4200, 1.0, 1, 0, 0, 0, 0);

INSERT OR IGNORE INTO "server_battlenpc_groups" ("groupId", "poolId", "scriptName", "minLevel", "maxLevel", "respawnTime", "hp", "mp", "dropListId", "allegiance", "spawnType", "animationId", "actorState", "privateAreaName", "privateAreaLevel", "zoneId") VALUES
    (30138, 30125, 'gcg301_hungry_dreadwolf', 24, 26, 60, 700, 0, 0, 0, 0, 0, 0, '', 0, 152);

INSERT OR IGNORE INTO "server_battlenpc_spawn_locations" ("bnpcId", "customDisplayName", "groupId", "positionX", "positionY", "positionZ", "rotation") VALUES
    (3566, 'gcg301_hungry_dreadwolf', 30138, -1443.8, 21.3, -1769.6, 1.0),
    (3567, 'gcg301_hungry_dreadwolf', 30138, -1435.0, 21.2, -1760.5, 2.0),
    (3568, 'gcg301_hungry_dreadwolf', 30138, -1453.0, 21.6, -1755.5, 3.0),
    (3569, 'gcg301_hungry_dreadwolf', 30138, -1431.0, 21.8, -1781.0, 0.5),
    (3570, 'gcg301_hungry_dreadwolf', 30138, -1461.7, 21.4, -1775.9, 1.5);
