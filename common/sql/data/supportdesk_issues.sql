-- supportdesk_issues: game data, 4 rows. Reloaded whole when this file changes.
SET SESSION sql_mode = 'ANSI_QUOTES,PIPES_AS_CONCAT,STRICT_ALL_TABLES,NO_AUTO_VALUE_ON_ZERO,NO_ENGINE_SUBSTITUTION';
DELETE FROM `supportdesk_issues`;
INSERT INTO `supportdesk_issues` (`slot`, `title`) VALUES
(0, 'Report Harassment'),
(1, 'Report Cheating'),
(2, 'Report a Bug or Glitch'),
(3, 'Leave Suggestion');
