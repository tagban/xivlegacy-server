require ("global")
require ("questbattle")
require ("quests/etc/etc2g4")

-- To Deskunk A Beer (Etc2g4): sourleaf roselets east of Humblehearth.
-- Content SimpleContentEtc2g401; a win is handled in quests/etc/etc2g4.lua.

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorEtc2g401";
end

function onEventStarted(player, actor, triggerName)
	questBattle.runDirector(player, actor, 110668, winEtc2g4Fight);
end

function main()
end
