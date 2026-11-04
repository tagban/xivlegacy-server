-- supportdesk_faqs: game data, 1 rows. Reloaded whole when this file changes.
SET SESSION sql_mode = 'ANSI_QUOTES,PIPES_AS_CONCAT,STRICT_ALL_TABLES,NO_AUTO_VALUE_ON_ZERO,NO_ENGINE_SUBSTITUTION';
DELETE FROM `supportdesk_faqs`;
INSERT INTO `supportdesk_faqs` (`slot`, `languageCode`, `title`, `body`) VALUES
(0, 1, 'Welcome to FFXIV Classic', 'Welcome to the FFXIV 1.0 server emulator FFXIVClassic!

This is still currently a work in progress, and you may find bugs or issues as you play with this server. Keep in mind that this is not even remotely close to being finished, and that it is a work in progress.

Check out the blog at: 
http://ffxivclassic.fragmenterworks.com/ 
Check out videos at: 
https://www.youtube.com/channel/UCr2703_er1Dj7Lx5pzpQpfg');
