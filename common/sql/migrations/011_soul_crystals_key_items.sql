-- Soul crystals are key items. The client's Lua names item packages by
-- wire code + 1, so the gear window's soul crystal check, hasItem(101, ...),
-- reads the key items (wire package 100), and crystals kept in a package
-- 101 never showed up. Move them into package 100, after the key items
-- already there.
UPDATE characters_inventory ci
JOIN (
    SELECT j.characterId, j.serverItemId,
           (SELECT COALESCE(MAX(k.slot), -1) FROM characters_inventory k
             WHERE k.characterId = j.characterId AND k.itemPackage = 100)
           + ROW_NUMBER() OVER (PARTITION BY j.characterId ORDER BY j.slot) AS newSlot
    FROM characters_inventory j
    WHERE j.itemPackage = 101
) m ON m.characterId = ci.characterId AND m.serverItemId = ci.serverItemId
SET ci.itemPackage = 100, ci.slot = m.newSlot
WHERE ci.itemPackage = 101;
