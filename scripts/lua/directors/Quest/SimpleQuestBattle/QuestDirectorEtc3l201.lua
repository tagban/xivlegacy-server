require ("global")
require ("questbattle")
require ("quests/etc/etc3l2")

-- Shot Through the Heart (Etc3l2): the beach east of Cassiopeia Hollow.
-- Content SimpleContentEtc3l201; a win is handled in quests/etc/etc3l2.lua.

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorEtc3l201";
end

function onEventStarted(player, actor, triggerName)
	questBattle.runDirector(player, actor, 110745, winEtc3l2Fight);
end

function main()
end
