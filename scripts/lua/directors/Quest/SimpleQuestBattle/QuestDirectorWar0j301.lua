require ("global")
require ("questbattle")
require ("jobquest_fights")

-- The client's SimpleQuestBattle director for War0j3's condor fight; the
-- fight's win is looked up in jobQuest.fights (see jobquest.lua).

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorWar0j301";
end

function onEventStarted(player, actor, triggerName)
	jobQuest.runFightDirector(player, actor);
end

function main()
end
