require ("global")
require ("questbattle")
require ("quests/etc/etc1u8")

-- Traumaturgy (Etc1u8): Theda's captors below the mesa northeast of Halatali.
-- Content SimpleContentEtc1u801; a win is handled in quests/etc/etc1u8.lua.

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorEtc1u801";
end

function onEventStarted(player, actor, triggerName)
	questBattle.runDirector(player, actor, 110683, winEtc1u8Fight);
end

function main()
end
