require ("global")
require ("questbattle")
require ("quests/etc/etc2g5")

-- Losing One's Thread (Etc2g5): the goblins east of Camp Tranquil.
-- Content SimpleContentEtc2g501; a win is handled in quests/etc/etc2g5.lua.

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorEtc2g501";
end

function onEventStarted(player, actor, triggerName)
	questBattle.runDirector(player, actor, 110669, winEtc2g5Fight);
end

function main()
end
