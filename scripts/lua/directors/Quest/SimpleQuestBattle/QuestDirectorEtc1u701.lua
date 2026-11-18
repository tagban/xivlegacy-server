require ("global")
require ("questbattle")
require ("quests/etc/etc1u7")

-- Clasping to Hope (Etc1u7): the Amalj'aa warband near Halatali.
-- Content SimpleContentEtc1u701; a win is handled in quests/etc/etc1u7.lua.

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorEtc1u701";
end

function onEventStarted(player, actor, triggerName)
	questBattle.runDirector(player, actor, 110682, winEtc1u7Fight);
end

function main()
end
