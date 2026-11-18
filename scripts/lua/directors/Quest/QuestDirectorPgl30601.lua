require ("global")
require ("questbattle")
require ("quests/pgl/pgl306")

-- Two Sides to Every Chip (Pgl306): the Ossuary's thaumaturge on the plateau
-- by the Silver Bazaar. The client's QuestDirectorPgl30601 is a plain
-- QuestDirectorBaseClass. Content SimpleContentPgl30601; a win is handled in
-- quests/pgl/pgl306.lua.

function init()
	return "/Director/Quest/QuestDirectorPgl30601";
end

function onEventStarted(player, actor, triggerName)
	questBattle.runDirector(player, actor, 110062, winPgl306Fight);
end

function main()
end
