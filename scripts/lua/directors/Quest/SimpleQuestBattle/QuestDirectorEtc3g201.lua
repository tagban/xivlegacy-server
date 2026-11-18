require ("global")
require ("questbattle")
require ("quests/etc/etc3g2")

-- Disorganized Crime (Etc3g2): the Redbelly Wasps at Lifemend Stump.
-- Content SimpleContentEtc3g201; a win is handled in quests/etc/etc3g2.lua.

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorEtc3g201";
end

function onEventStarted(player, actor, triggerName)
	questBattle.runDirector(player, actor, 110736, winEtc3g2Fight);
end

function main()
end
