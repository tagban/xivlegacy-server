-- Prying Eyes (Gcu301), the Immortal Flames' errand for Eshtaime's
-- Lapidaries (scripts/lua/quests/gcu/gcu301.lua). Lefchild already stands in
-- the Goldsmiths' Guild. This adds:
--
-- * Coblyns on the slope northwest of Camp Horizon (Western Thanalan, zone
--   172) for Lefchild's bright eye. The mesas east of the camp sit past a
--   wall the player can't cross, so the coblyns graze the open ground on
--   the camp's other side, among the same mesas.
--
-- Heights walked in the test client (the client keeps a warp's height, so
-- each point is a spot the player stood on).
--
-- Idempotent: INSERTs OR IGNORE on id. No schema change.

INSERT OR IGNORE INTO "server_battlenpc_pools" ("poolId", "actorClassId", "name", "genusId", "currentJob", "combatSkill", "combatDelay", "combatDmgMult", "aggroType", "immunity", "linkType", "spellListId", "skillListId") VALUES
    (30116, 2102125, 'Coblyn', 49, 0, 1, 4200, 1.0, 0, 0, 0, 0, 0);

INSERT OR IGNORE INTO "server_battlenpc_groups" ("groupId", "poolId", "scriptName", "minLevel", "maxLevel", "respawnTime", "hp", "mp", "dropListId", "allegiance", "spawnType", "animationId", "actorState", "privateAreaName", "privateAreaLevel", "zoneId") VALUES
    (30127, 30116, 'gcu301_coblyn', 25, 27, 60, 600, 0, 0, 0, 0, 0, 0, '', 0, 172);

INSERT OR IGNORE INTO "server_battlenpc_spawn_locations" ("bnpcId", "customDisplayName", "groupId", "positionX", "positionY", "positionZ", "rotation") VALUES
    (3534, 'gcu301_coblyn', 30127, -1358.3, 54.85, -139.1, 0.0),
    (3535, 'gcu301_coblyn', 30127, -1364.2, 52.73, -114.7, 1.0),
    (3536, 'gcu301_coblyn', 30127, -1370.3, 51.18,  -89.7, 2.0),
    (3537, 'gcu301_coblyn', 30127, -1376.2, 49.39,  -65.0, 3.0),
    (3538, 'gcu301_coblyn', 30127, -1368.7, 49.29,  -72.6, 4.0),
    (3539, 'gcu301_coblyn', 30127, -1373.3, 49.35,  -56.0, 5.0);
