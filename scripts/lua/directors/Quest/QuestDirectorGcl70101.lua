-- The Weakest Link's War Merit duty (content SimpleContentGcl70101). The
-- director is shared by the three nations: runGc701Director in
-- quests/gc/gc701.lua.

NATION = 1;
require ("quests/gc/gc701")

function init()
	return "/Director/Quest/QuestDirectorGcl70101";
end

function onEventStarted(player, actor, triggerName)
	runGc701Director(player, actor);
end

function main()
end
