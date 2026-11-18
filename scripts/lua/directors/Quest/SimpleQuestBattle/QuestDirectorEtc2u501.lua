require ("global")
require ("questbattle")
require ("quests/etc/etc2u5")

-- No Other Dodo Will Do (Etc2u5): three clever dodos north of Camp Drybone.
-- Content SimpleContentEtc2u501; a win is handled in quests/etc/etc2u5.lua.

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorEtc2u501";
end

function onEventStarted(player, actor, triggerName)
	questBattle.runDirector(player, actor, 110690, winEtc2u5Fight);
end

function main()
end
