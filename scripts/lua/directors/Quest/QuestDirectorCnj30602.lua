require ("global")
require ("questbattle")
require ("quests/cnj/cnj306")

-- The Call of Nature (Cnj306): the dreadwolves in Morys's past, in the Echo.
-- The client's QuestDirectorCnj30602 is a plain QuestDirectorBaseClass.
-- Content SimpleContentCnj30602; a win is handled in quests/cnj/cnj306.lua.

function init()
	return "/Director/Quest/QuestDirectorCnj30602";
end

function onEventStarted(player, actor, triggerName)
	questBattle.runDirector(player, actor, 110262, winCnj306Fight);
end

function main()
end
