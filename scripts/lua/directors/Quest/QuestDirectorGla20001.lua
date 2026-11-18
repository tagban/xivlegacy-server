require ("global")
require ("modifiers")
require ("quests/gla/gla200")

-- Gla200's preliminary bout (content SimpleContentGla20001). The entry kick
-- raises the loading veil, so it is lifted and the kick closed; a win is
-- handled by finishGla200Bout in quests/gla/gla200.lua.

function init()
	return "/Director/Quest/QuestDirectorGla20001";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(110080);
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A bout that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	finishGla200Bout(player, quest, actor);
end

function main()
end
