require ("global")
require ("questbattle")
require ("quests/etc/etc3g1")

-- Scrubbing the Soul (Etc3g1): three imperial soldiers by the scarred tree south of Camp Bentbranch.
-- Content SimpleContentEtc3g101; a win is handled in quests/etc/etc3g1.lua.

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorEtc3g101";
end

function onEventStarted(player, actor, triggerName)
	questBattle.runDirector(player, actor, 110735, winEtc3g1Fight);
end

function main()
end
