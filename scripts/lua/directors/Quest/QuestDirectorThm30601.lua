require ("global")
require ("modifiers")
require ("quests/thm/thm306")

-- Thm306's fight with the overweening thaumaturge (content
-- SimpleContentThm30601). The entry kick raises the loading veil, so it is
-- lifted and the kick closed; a win is handled by finishThm306Fight in
-- quests/thm/thm306.lua.

function init()
	return "/Director/Quest/QuestDirectorThm30601";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(110242);
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A fight that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	finishThm306Fight(player, quest, actor);
end

function main()
end
