-- Status effect fixes from the status audit (battle/status-effects).
--
-- 1. A combat hook only runs for an effect whose flags ask for it
--    (StatusEffectFlags ACTIVATE_ON_*). These scripts had hooks their
--    flags didn't ask for, so the hooks never ran:
--    - Sacred Prism: onMagicCast (cast start, 1 << 9) and onCommandFinish
--      (command finish, 1 << 11). 9 -> 2569.
--    - Antagonize: its enmity boost is an onCommandStart (1 << 10); the
--      row asked for onHit instead. 1048601 -> 1049625.
-- 2. Effects that had no script now have one, with the flag its hook needs:
--    - Paralysis: onPreAction as the attacker (1 << 13). 21 -> 8213.
--    - Presence of Mind: onPreAction as the target (1 << 12). 9 -> 4105.
--    - Shroud of Saints: onCommandStart (1 << 10). 9 -> 1033.
UPDATE server_statuseffects SET flags = 2569 WHERE id = 223225;
UPDATE server_statuseffects SET flags = 1049625 WHERE id = 223251;
UPDATE server_statuseffects SET flags = 8213 WHERE id = 223005;
UPDATE server_statuseffects SET flags = 4105 WHERE id = 223116;
UPDATE server_statuseffects SET flags = 1033 WHERE id = 223226;

-- 3. Aerora and Stonera are circle area spells (aoeType 1) with a range of
--    0, so they only ever hit their main target. Every other -ra spell
--    (Blizzara, Fira) uses an 8 yalm circle around the target.
UPDATE server_battle_commands SET aoeRange = 8.0 WHERE id IN (27354, 27356);
