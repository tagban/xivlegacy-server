require ("global")
require ("questbattle")
require ("quests/etc/etc2l1")

-- Moonstruck (Etc2l1): two aldgoat nannies, a moraby mole and a black bat on the road from Wineport to Bloodshore.
-- Content SimpleContentEtc2l101; a win is handled in quests/etc/etc2l1.lua.

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorEtc2l101";
end

function onEventStarted(player, actor, triggerName)
	questBattle.runDirector(player, actor, 110644, winEtc2l1Fight);
end

function main()
end
