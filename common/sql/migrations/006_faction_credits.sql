-- Faction credits: what a character holds with each faction (1 Brotherhood
-- of the Broken Blade, 2 Azeyma's Shields, 3 the Horn and Hand). The
-- levemete's faction menu shows the totals and a faction leve costs its
-- factionCreditRequired when accepted. The client caps a faction at 1,000.

CREATE TABLE IF NOT EXISTS characters_faction_credit (
    characterId BIGINT NOT NULL,
    faction     BIGINT NOT NULL,
    credits     BIGINT NOT NULL DEFAULT 0,
    PRIMARY KEY (characterId, faction)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
