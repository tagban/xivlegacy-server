require ("global")
require ("questbattle")
require ("jobquest_fights")

-- One of the client's SimpleQuestBattle directors for the job quests. It
-- serves every job quest fight, not only War0j1's: the fight the player
-- is in is looked up in jobQuest.fights (see jobquest.lua).

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorWar0j101";
end

function onEventStarted(player, actor, triggerName)
	jobQuest.runFightDirector(player, actor);
end

function main()
end
