require ("global")
require ("questbattle")
require ("quests/cnj/cnj300")

-- Good Knight, Sweet Dreams (Cnj300): the angry elementals at Amberscale Rock.
-- The client's QuestDirectorCnj30001 is a plain QuestDirectorBaseClass.
-- Content SimpleContentCnj30001; a win is handled in quests/cnj/cnj300.lua.

function init()
	return "/Director/Quest/QuestDirectorCnj30001";
end

function onEventStarted(player, actor, triggerName)
	questBattle.runDirector(player, actor, 110261, winCnj300Fight);
end

function main()
end
