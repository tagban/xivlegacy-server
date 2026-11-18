-- Knockback level of a monster move (0 = none, 1-5 = push strength,
-- the client's knockback hit-effect levels). Set from archived 1.0 wiki
-- pages that say the move knocks back; the strength is a guess.
ALTER TABLE server_battlenpc_skill_info
    ADD COLUMN knockback BIGINT NOT NULL DEFAULT 0 AFTER modernActionId;
