require ("global")
require ("modifiers")
require ("quests/pgl/pgl200")

-- Pgl200's bloodsands match (content SimpleContentPgl20002). The entry kick
-- raises the loading veil, so it is lifted and the kick closed; the match
-- result is handled by finishPgl200Coliseum in quests/pgl/pgl200.lua.

function init()
	return "/Director/Quest/QuestDirectorPgl20002";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(110060);
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A duty that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	finishPgl200Coliseum(player, quest, actor);
end

function main()
end
