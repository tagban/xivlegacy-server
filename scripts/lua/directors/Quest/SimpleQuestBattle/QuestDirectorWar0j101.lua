require ("global")
require ("questbattle")
require ("quests/war/war0j1")

-- Pride and Duty (War0j1): the antlings nesting north of Curious Gorge's cave.
-- Content SimpleContentWar0j101; a win is handled in quests/war/war0j1.lua.

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorWar0j101";
end

function onEventStarted(player, actor, triggerName)
	questBattle.runDirector(player, actor, 111201, winWar0j1Fight);
end

function main()
end
