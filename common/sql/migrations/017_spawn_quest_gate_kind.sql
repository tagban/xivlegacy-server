-- Quest cast in the open world: server_spawn_location_quests gets a `gate`
-- column saying when a listed spawn is sent to a player.
--   'quest'  while the player holds the quest, at any step (what every row
--            meant until now: the Echo casts of a shared private area).
--   'step'   while the player holds the quest and its current step names
--            the NPC's class (quest:SetENpc in the quest's onStateChange).
-- A spawn goes to a player when any of its rows' gates is open; a spawn
-- with no rows goes to everyone.
ALTER TABLE `server_spawn_location_quests`
    ADD COLUMN IF NOT EXISTS `gate` VARCHAR(8) NOT NULL DEFAULT 'quest' AFTER `questId`;
