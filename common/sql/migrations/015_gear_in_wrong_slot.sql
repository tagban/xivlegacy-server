-- Armor stored in a gear slot it doesn't belong in. The login backfill
-- (player.lua equipClassItems) equips fixed bag positions into fixed gear
-- slots, which only fits a fresh character's starter kit; with any other
-- bag it put a robe in the head slot, chausses in the body slot and so on.
-- EquipCommand also took any slot the client sent. The client draws a robe
-- on the head as a plain white hat.
--
-- 1. Note the characters that have such rows.
-- 2. Unequip those rows. The items stay in the bag. Weapons, tools and
--    anything else without an armor equipPoint are left alone.
-- 3. Redraw those characters' saved armor look for the class they're on, the
--    way the server draws it (equip.rs gear_graphic): body falls back to the
--    undershirt, legs to the undergarment, bare hands and feet are 1024.

CREATE TABLE IF NOT EXISTS _gear_fix_chars (
    characterId BIGINT NOT NULL PRIMARY KEY
);

INSERT IGNORE INTO _gear_fix_chars (characterId)
SELECT DISTINCT cie.characterId
FROM characters_inventory_equipment cie
JOIN server_items si ON si.id = cie.itemId
JOIN gamedata_items_equipment e ON e.catalogID = si.itemId
WHERE (e.equipPoint = 9  AND cie.equipSlot <> 8)
   OR (e.equipPoint = 10 AND cie.equipSlot <> 9)
   OR (e.equipPoint = 11 AND cie.equipSlot <> 10)
   OR (e.equipPoint = 12 AND cie.equipSlot <> 11)
   OR (e.equipPoint = 13 AND cie.equipSlot <> 12)
   OR (e.equipPoint = 14 AND cie.equipSlot <> 13)
   OR (e.equipPoint = 15 AND cie.equipSlot <> 14)
   OR (e.equipPoint = 16 AND cie.equipSlot <> 15)
   OR (e.equipPoint = 17 AND cie.equipSlot <> 16)
   OR (e.equipPoint = 47 AND cie.equipSlot <> 17)
   OR (e.equipPoint = 45 AND cie.equipSlot <> 19)
   OR (e.equipPoint = 49 AND cie.equipSlot NOT IN (21, 22));

DELETE cie
FROM characters_inventory_equipment cie
JOIN server_items si ON si.id = cie.itemId
JOIN gamedata_items_equipment e ON e.catalogID = si.itemId
WHERE (e.equipPoint = 9  AND cie.equipSlot <> 8)
   OR (e.equipPoint = 10 AND cie.equipSlot <> 9)
   OR (e.equipPoint = 11 AND cie.equipSlot <> 10)
   OR (e.equipPoint = 12 AND cie.equipSlot <> 11)
   OR (e.equipPoint = 13 AND cie.equipSlot <> 12)
   OR (e.equipPoint = 14 AND cie.equipSlot <> 13)
   OR (e.equipPoint = 15 AND cie.equipSlot <> 14)
   OR (e.equipPoint = 16 AND cie.equipSlot <> 15)
   OR (e.equipPoint = 17 AND cie.equipSlot <> 16)
   OR (e.equipPoint = 47 AND cie.equipSlot <> 17)
   OR (e.equipPoint = 45 AND cie.equipSlot <> 19)
   OR (e.equipPoint = 49 AND cie.equipSlot NOT IN (21, 22));

-- The armor graphic in each slot of the class they're on (undergarments
-- are stored under class 0).
CREATE TABLE IF NOT EXISTS _gear_fix_look (
    characterId BIGINT NOT NULL,
    equipSlot BIGINT NOT NULL,
    graphic BIGINT NOT NULL,
    PRIMARY KEY (characterId, equipSlot)
);

INSERT IGNORE INTO _gear_fix_look (characterId, equipSlot, graphic)
SELECT cie.characterId, cie.equipSlot,
       (g.equipmentId << 10) | ((g.variantId & 31) << 5) | g.colorId
FROM _gear_fix_chars f
JOIN characters_parametersave ps ON ps.characterId = f.characterId
JOIN characters_inventory_equipment cie
  ON cie.characterId = f.characterId AND cie.classId IN (ps.mainSkill, 0)
JOIN server_items si ON si.id = cie.itemId
JOIN gamedata_items_graphics g ON g.catalogID = si.itemId
WHERE cie.equipSlot BETWEEN 8 AND 16 AND g.weaponId = 0;

UPDATE characters_appearance ca
JOIN _gear_fix_chars f ON f.characterId = ca.characterId
SET ca.head  = COALESCE((SELECT graphic FROM _gear_fix_look l WHERE l.characterId = ca.characterId AND l.equipSlot = 8), 0),
    ca.body  = COALESCE((SELECT graphic FROM _gear_fix_look l WHERE l.characterId = ca.characterId AND l.equipSlot = 10),
                        (SELECT graphic FROM _gear_fix_look l WHERE l.characterId = ca.characterId AND l.equipSlot = 9), 0),
    ca.legs  = COALESCE((SELECT graphic FROM _gear_fix_look l WHERE l.characterId = ca.characterId AND l.equipSlot = 12),
                        (SELECT graphic FROM _gear_fix_look l WHERE l.characterId = ca.characterId AND l.equipSlot = 11), 0),
    ca.hands = COALESCE((SELECT graphic FROM _gear_fix_look l WHERE l.characterId = ca.characterId AND l.equipSlot = 13), 1024),
    ca.feet  = COALESCE((SELECT graphic FROM _gear_fix_look l WHERE l.characterId = ca.characterId AND l.equipSlot = 14), 1024),
    ca.waist = COALESCE((SELECT graphic FROM _gear_fix_look l WHERE l.characterId = ca.characterId AND l.equipSlot = 15), 0),
    ca.neck  = COALESCE((SELECT graphic FROM _gear_fix_look l WHERE l.characterId = ca.characterId AND l.equipSlot = 16), 0);

DROP TABLE _gear_fix_look;
DROP TABLE _gear_fix_chars;
