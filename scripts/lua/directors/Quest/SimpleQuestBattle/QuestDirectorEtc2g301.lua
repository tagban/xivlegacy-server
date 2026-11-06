require ("global")
require ("questbattle")
require ("quests/etc/etc2g3")

-- Hunting the Hunters (Etc2g3): four Ixali bravos near Quarrymill.
-- Content SimpleContentEtc2g301; a win is handled in quests/etc/etc2g3.lua.

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorEtc2g301";
end

function onEventStarted(player, actor, triggerName)
	questBattle.runDirector(player, actor, 110667, winEtc2g3Fight);
end

function main()
end
