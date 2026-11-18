-- You Don't Have the Rite's War Merit duty (content SimpleContentGcg70101). The
-- director is shared by the three nations: runGc701Director in
-- quests/gc/gc701.lua.

NATION = 2;
require ("quests/gc/gc701")

function init()
	return "/Director/Quest/QuestDirectorGcg70101";
end

function onEventStarted(player, actor, triggerName)
	runGc701Director(player, actor);
end

function main()
end
