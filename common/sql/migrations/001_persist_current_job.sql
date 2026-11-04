-- Keep the job a character is in across logins. The job lived only in the
-- map server's memory, so a relog dropped every player back to their base
-- class. 0 = no job (playing the class in mainSkill).
ALTER TABLE characters_parametersave
    ADD COLUMN currentJob BIGINT NOT NULL DEFAULT 0 AFTER mainSkillLevel;
