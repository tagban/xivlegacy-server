require ("global")
require ("questbattle")
require ("quests/etc/etc1u9")

-- Best Flower Ever (Etc1u9): the rabid dodos in the valley below Sasapano.
-- Content SimpleContentEtc1u901; a win is handled in quests/etc/etc1u9.lua.

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorEtc1u901";
end

function onEventStarted(player, actor, triggerName)
	questBattle.runDirector(player, actor, 110684, winEtc1u9Fight);
end

function main()
end
