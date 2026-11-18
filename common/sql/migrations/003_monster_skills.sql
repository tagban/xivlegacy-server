-- Monster skills. A skill list held one skill (the key was skillListId
-- alone); key it by (list, skill) so a family's list can hold all its
-- moves, and record how sure we are of each entry.
ALTER TABLE server_battlenpc_skill_list
    DROP PRIMARY KEY,
    ADD COLUMN evidence VARCHAR(16) NOT NULL DEFAULT '' AFTER skillId,
    ADD PRIMARY KEY (skillListId, skillId);

-- One row per 1.0 monster move (client command sheet 23011-23645): which
-- family uses it and the evidence for that, its animation slot, and the
-- modern (ARR+) Action it was filled in from where 1.0 data is missing.
-- evidence: zam   = a ZAM monster page shows that family using this move
--           block = in the same id block as a ZAM-confirmed move
--           name  = family inferred from the move names / modern owner
--           ''    = family not known yet
CREATE TABLE IF NOT EXISTS server_battlenpc_skill_info (
    skillId        BIGINT NOT NULL,
    displayName    VARCHAR(64) NOT NULL,
    genusId        BIGINT NOT NULL DEFAULT 0,
    evidence       VARCHAR(16) NOT NULL DEFAULT '',
    slot           BIGINT NOT NULL DEFAULT 0,
    modernActionId BIGINT NOT NULL DEFAULT 0,
    notes          VARCHAR(255) NOT NULL DEFAULT '',
    PRIMARY KEY (skillId),
    KEY skill_info_genus (genusId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
