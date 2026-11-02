-- Battle-command data fixes found by the battle_command_audit harness
-- (map-server/src/runtime/battle_audit_tests.rs).
--
-- 1. Seven statuses that battle commands apply had no server_statuseffects
--    row, so they got no flags (stance, lose-on-death, esuna-able) and no
--    overwrite rule: Provoke's Attack Down, Taunt, Presence of Mind, Sacred
--    Prism, Shroud of Saints, Hallowed Ground and Flare's lingering effect.
--    Buffs use the stock buff shape (lose on death / dispel, gain 30328,
--    loss 30331), debuffs the stock debuff shape (lose on death / esuna /
--    logout, gain 30335, loss 30338) - the same values seed 032 uses for
--    their neighbors.
INSERT OR IGNORE INTO "server_statuseffects" ("id", "name", "flags", "overwrite", "tickMs", "hidden", "silentOnGain", "silentOnLoss", "statusGainTextId", "statusLossTextId") VALUES
    (223034, 'attack_down', 21, 2, 0, 0, 0, 0, 30335, 30338),
    (223073, 'taunted', 21, 2, 0, 0, 0, 0, 30335, 30338),
    (223116, 'presence_of_mind', 9, 2, 0, 0, 0, 0, 30328, 30331),
    (223225, 'sacred_prism', 9, 2, 0, 0, 0, 0, 30328, 30331),
    (223226, 'shroud_of_saints', 9, 2, 0, 0, 0, 0, 30328, 30331),
    (223249, 'hallowed_ground', 9, 2, 0, 0, 0, 0, 30328, 30331),
    (223262, 'flare2', 21, 2, 0, 0, 0, 0, 30335, 30338);

-- 2. Shoulder Tackle (MNK) deals damage and may stun (its script calls
--    DoAction with the base potency, then TryStatus), and the row already
--    carries the physical hit text 30301 and an attack animation - but its
--    actionType was 4 (status), so it never dealt damage. Physical = 1.
UPDATE server_battle_commands SET actionType = 1 WHERE id = 27108;

-- 3. Holy Succor (PLD) is a heal with no status, but its text was 30328
--    ("Your <command> grants you the effect of <status>"), which reads a
--    status id out of the heal row's effect field. Use the heal text 30320
--    that Cure, Cura, Curaga and Second Wind use.
UPDATE server_battle_commands SET worldMasterTextId = 30320 WHERE id = 27149;
