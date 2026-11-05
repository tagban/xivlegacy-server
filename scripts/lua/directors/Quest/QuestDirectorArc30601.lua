require ("global")
require ("modifiers")
require ("quests/arc/arc306")

-- Arc306's fight with Siward (content SimpleContentArc30601). The entry
-- kick raises the loading veil, so it is lifted and the kick closed; a win
-- is handled by finishArc306Fight in quests/arc/arc306.lua.

function init()
	return "/Director/Quest/QuestDirectorArc30601";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(110162);
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A fight that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	finishArc306Fight(player, quest, actor);
end

function main()
end
