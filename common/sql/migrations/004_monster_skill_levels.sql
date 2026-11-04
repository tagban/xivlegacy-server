-- Level gate for monster moves: a monster below minLevel can't use that
-- move from its list (a level 9 aldgoat can't use a level 10 move).
-- levelSource says where the level came from:
--   modern = lowest level of an open-world monster using it in ARR+
--   spawn  = estimate: the kind's moves spread over its spawn levels here,
--            in client order (no 1.0 level data survives)
--   boss   = a named monster's own move, usable at any level
ALTER TABLE server_battlenpc_skill_list
    ADD COLUMN minLevel BIGINT NOT NULL DEFAULT 1 AFTER skillId,
    ADD COLUMN levelSource VARCHAR(16) NOT NULL DEFAULT '' AFTER minLevel;

-- Lists are per monster kind (one model family: its moves share animation
-- slots), not strictly per genus: yarzons sit under the rodent genus but
-- have their own moves, and named bosses (Ifrit, Garuda, Nael) have their
-- own lists keyed by their pool id. skill_info records the list and the
-- kind's display name.
ALTER TABLE server_battlenpc_skill_info
    ADD COLUMN skillListId BIGINT NOT NULL DEFAULT 0 AFTER genusId,
    ADD COLUMN family VARCHAR(32) NOT NULL DEFAULT '' AFTER skillListId;
