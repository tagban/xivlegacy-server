require ("global")
require ("questbattle")
require ("quests/etc/etc3u2")

-- There Might Be Blood (Etc3u2): the Coliseum yarzon at Little Ala Mhigo.
-- Content SimpleContentEtc3u201; a win is handled in quests/etc/etc3u2.lua.

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorEtc3u201";
end

function onEventStarted(player, actor, triggerName)
	questBattle.runDirector(player, actor, 110727, winEtc3u2Fight);
end

function main()
end
