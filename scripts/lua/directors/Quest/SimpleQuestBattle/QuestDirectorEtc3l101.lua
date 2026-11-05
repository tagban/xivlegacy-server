require ("global")
require ("questbattle")
require ("quests/etc/etc3l1")

-- Winds of Change (Etc3l1): three imperial operatives in the caves west of Camp Bearded Rock.
-- Content SimpleContentEtc3l101; a win is handled in quests/etc/etc3l1.lua.

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorEtc3l101";
end

function onEventStarted(player, actor, triggerName)
	questBattle.runDirector(player, actor, 110744, winEtc3l1Fight);
end

function main()
end
