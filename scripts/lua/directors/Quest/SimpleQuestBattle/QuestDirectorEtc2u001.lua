require ("global")
require ("questbattle")
require ("quests/etc/etc2u0")

-- The Unheard Horizon (Etc2u0): two coblyns, a spriggan and a feral dodo on the outskirts of Camp Horizon.
-- Content SimpleContentEtc2u001; a win is handled in quests/etc/etc2u0.lua.

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorEtc2u001";
end

function onEventStarted(player, actor, triggerName)
	questBattle.runDirector(player, actor, 110685, winEtc2u0Fight);
end

function main()
end
