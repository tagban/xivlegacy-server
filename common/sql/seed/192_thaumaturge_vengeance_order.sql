-- Thm200 (scripts/lua/quests/thm/thm200.lua): the Thaumaturges' Guild's
-- first vengeance order. The death-marked billygoat (2202303) roams with the
-- aldgoat herd in Western Thanalan (zone 172, seed 101 groups 10160/10161)
-- and respawns after a minute, so anyone on the quest can find it. The
-- spot sits between two of the herd's spawn points, at their height.
--
-- Idempotent: INSERT OR IGNORE on id. No schema change.

INSERT OR IGNORE INTO "server_battlenpc_pools" ("poolId", "actorClassId", "name", "genusId", "currentJob", "combatSkill", "combatDelay", "combatDmgMult", "aggroType", "immunity", "linkType", "spellListId", "skillListId") VALUES
    (30210, 2202303, 'Death-marked Billygoat', 1, 0, 1, 4200, 1.0, 0, 0, 0, 0, 0);

INSERT OR IGNORE INTO "server_battlenpc_groups" ("groupId", "poolId", "scriptName", "minLevel", "maxLevel", "respawnTime", "hp", "mp", "dropListId", "allegiance", "spawnType", "animationId", "actorState", "privateAreaName", "privateAreaLevel", "zoneId") VALUES
    (30310, 30210, 'thm200_death_marked_billygoat', 22, 22, 60, 900, 0, 0, 0, 0, 0, 0, '', 0, 172);

INSERT OR IGNORE INTO "server_battlenpc_spawn_locations" ("bnpcId", "customDisplayName", "groupId", "positionX", "positionY", "positionZ", "rotation") VALUES
    (3922, 'thm200_death_marked_billygoat', 30310, -1150.5, 54.3, -340.0, 1.2);
