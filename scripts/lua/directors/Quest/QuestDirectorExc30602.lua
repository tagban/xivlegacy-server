require ("global")
require ("modifiers")
require ("quests/exc/exc306")

-- Exc306's fight with Moenskaet and his hands (content
-- SimpleContentExc30602). The entry kick raises the loading veil, so it is
-- lifted and the kick closed; a win is handled by finishExc306Fight in
-- quests/exc/exc306.lua.

function init()
	return "/Director/Quest/QuestDirectorExc30602";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(110102);
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A fight that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	finishExc306Fight(player, quest, actor);
end

function main()
end
