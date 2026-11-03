-- Skill power for battle commands (seed 291).
--
-- Every row in 013 carries basePotency 100, so every skill hit the same.
-- These columns hold what the damage and healing formula reads instead:
--
--   magicPotency   spell (and stat-scaled ability) power, 1000 = 1.0x. From
--                  the 1.x command data as transcribed in the Project Meteor
--                  era BattleCommand workbook (the same source as 013's MP
--                  costs, cast and recast times); 0 = not a stat-scaled skill.
--   mainStat/secondStat  the stat it scales with (1 STR, 2 VIT, 3 DEX,
--                  4 INT, 5 MND, 6 PIE; -1 none) and how much (the *Mod).
--   damageMultiplier  a physical skill's damage as a multiple of the user's
--                  auto-attack. Fitted from retail 1.23b captures (XIVLegacy
--                  xivl-captures, CC BY 4.0: battle-result-actor-join), each
--                  skill's median hit over the same character's auto-attack
--                  on the same target level. 0 = the server default.

ALTER TABLE server_battle_commands ADD COLUMN magicPotency INTEGER NOT NULL DEFAULT 0;
ALTER TABLE server_battle_commands ADD COLUMN mainStat INTEGER NOT NULL DEFAULT -1;
ALTER TABLE server_battle_commands ADD COLUMN mainStatMod REAL NOT NULL DEFAULT 0;
ALTER TABLE server_battle_commands ADD COLUMN secondStat INTEGER NOT NULL DEFAULT -1;
ALTER TABLE server_battle_commands ADD COLUMN secondStatMod REAL NOT NULL DEFAULT 0;
ALTER TABLE server_battle_commands ADD COLUMN damageMultiplier REAL NOT NULL DEFAULT 0;

UPDATE server_battle_commands SET magicPotency = 1350, mainStat = -1, mainStatMod = 0, secondStat = -1, secondStatMod = 0 WHERE id = 23458; -- breath_of_the_dragon
UPDATE server_battle_commands SET magicPotency = 1300, mainStat = -1, mainStatMod = 0, secondStat = -1, secondStatMod = 0 WHERE id = 23459; -- voice_of_the_dragon
UPDATE server_battle_commands SET magicPotency = 1350, mainStat = -1, mainStatMod = 0, secondStat = -1, secondStatMod = 0 WHERE id = 23460; -- breath_of_the_ram
UPDATE server_battle_commands SET magicPotency = 1550, mainStat = 4, mainStatMod = 0.5, secondStat = -1, secondStatMod = 0 WHERE id = 27100; -- second_wind
UPDATE server_battle_commands SET damageMultiplier = 4.32 WHERE id = 27108; -- shoulder_tackle
UPDATE server_battle_commands SET damageMultiplier = 5.39 WHERE id = 27110; -- pummel
UPDATE server_battle_commands SET damageMultiplier = 5.90 WHERE id = 27111; -- concussive_blow
UPDATE server_battle_commands SET damageMultiplier = 5.25 WHERE id = 27119; -- haymaker
UPDATE server_battle_commands SET magicPotency = 1500, mainStat = 5, mainStatMod = 0.4, secondStat = -1, secondStatMod = 0 WHERE id = 27149; -- holy_succor
UPDATE server_battle_commands SET damageMultiplier = 3.10 WHERE id = 27150; -- fast_blade
UPDATE server_battle_commands SET damageMultiplier = 3.25 WHERE id = 27152; -- savage_blade
UPDATE server_battle_commands SET damageMultiplier = 2.55 WHERE id = 27156; -- shield_bash
UPDATE server_battle_commands SET damageMultiplier = 2.70 WHERE id = 27158; -- phalanx
UPDATE server_battle_commands SET damageMultiplier = 1.79 WHERE id = 27190; -- heavy_swing
UPDATE server_battle_commands SET damageMultiplier = 2.07 WHERE id = 27191; -- skull_sunder
UPDATE server_battle_commands SET damageMultiplier = 1.73 WHERE id = 27193; -- brutal_swing
UPDATE server_battle_commands SET damageMultiplier = 1.61 WHERE id = 27198; -- fracture
UPDATE server_battle_commands SET magicPotency = 1200, mainStat = 6, mainStatMod = 1.5, secondStat = -1, secondStatMod = 0 WHERE id = 27268; -- dragonfire_dive
UPDATE server_battle_commands SET magicPotency = 800, mainStat = 4, mainStatMod = 0.5, secondStat = -1, secondStatMod = 0 WHERE id = 27308; -- blizzard
UPDATE server_battle_commands SET magicPotency = 550, mainStat = 4, mainStatMod = 0.25, secondStat = -1, secondStatMod = 0 WHERE id = 27309; -- blizzara
UPDATE server_battle_commands SET magicPotency = 950, mainStat = 4, mainStatMod = 0.5, secondStat = -1, secondStatMod = 0 WHERE id = 27310; -- fire
UPDATE server_battle_commands SET magicPotency = 1200, mainStat = 4, mainStatMod = 1, secondStat = -1, secondStatMod = 0 WHERE id = 27311; -- fira
UPDATE server_battle_commands SET magicPotency = 1600, mainStat = 4, mainStatMod = 1.5, secondStat = -1, secondStatMod = 0 WHERE id = 27312; -- firaga
UPDATE server_battle_commands SET magicPotency = 1050, mainStat = 4, mainStatMod = 0.5, secondStat = -1, secondStatMod = 0 WHERE id = 27313; -- thunder
UPDATE server_battle_commands SET magicPotency = 500, mainStat = 4, mainStatMod = 1, secondStat = -1, secondStatMod = 0 WHERE id = 27314; -- thundara
UPDATE server_battle_commands SET magicPotency = 2150, mainStat = 4, mainStatMod = 1.5, secondStat = -1, secondStatMod = 0 WHERE id = 27315; -- thundaga
UPDATE server_battle_commands SET magicPotency = 2200, mainStat = 4, mainStatMod = 1.5, secondStat = -1, secondStatMod = 0 WHERE id = 27316; -- burst
UPDATE server_battle_commands SET magicPotency = 2000, mainStat = 4, mainStatMod = 1.5, secondStat = -1, secondStatMod = 0 WHERE id = 27318; -- flare
UPDATE server_battle_commands SET magicPotency = 1200, mainStat = 4, mainStatMod = 1.5, secondStat = -1, secondStatMod = 0 WHERE id = 27319; -- freeze
UPDATE server_battle_commands SET magicPotency = 1000, mainStat = 5, mainStatMod = 0.2, secondStat = -1, secondStatMod = 0 WHERE id = 27346; -- cure
UPDATE server_battle_commands SET magicPotency = 2000, mainStat = 5, mainStatMod = 0.4, secondStat = -1, secondStatMod = 0 WHERE id = 27347; -- cura
UPDATE server_battle_commands SET magicPotency = 4000, mainStat = 5, mainStatMod = 0.2, secondStat = -1, secondStatMod = 0 WHERE id = 27348; -- curaga
UPDATE server_battle_commands SET magicPotency = 800, mainStat = 4, mainStatMod = 0.25, secondStat = 5, secondStatMod = 0.25 WHERE id = 27353; -- aero
UPDATE server_battle_commands SET magicPotency = 1200, mainStat = 4, mainStatMod = 0.5, secondStat = 5, secondStatMod = 0.5 WHERE id = 27354; -- aerora
UPDATE server_battle_commands SET magicPotency = 950, mainStat = 4, mainStatMod = 0.25, secondStat = 5, secondStatMod = 0.25 WHERE id = 27355; -- stone
UPDATE server_battle_commands SET magicPotency = 950, mainStat = 4, mainStatMod = 0.5, secondStat = 5, secondStatMod = 0.5 WHERE id = 27356; -- stonera
UPDATE server_battle_commands SET magicPotency = 2000, mainStat = 4, mainStatMod = 1, secondStat = 5, secondStatMod = 1 WHERE id = 27359; -- holy
