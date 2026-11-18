require ("global")
require ("modifiers")
require ("quests/gla/gla306")

-- Gla306's Echo rematch with the Lalafell (content SimpleContentGla30602). The entry
-- kick raises the loading veil, so it is lifted and the kick closed; a win
-- is handled by finishGla306Bout in quests/gla/gla306.lua.

function init()
	return "/Director/Quest/QuestDirectorGla30602";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(110082);
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A bout that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	finishGla306Bout(player, quest, actor, true);
end

function main()
end
