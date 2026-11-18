require ("global")
require ("modifiers")
require ("quests/gla/gla300")

-- Gla300's spar with J'moldva (content SimpleContentGla30001). The entry kick
-- raises the loading veil, so it is lifted and the kick closed; a win is
-- handled by finishGla300Bout in quests/gla/gla300.lua.

function init()
	return "/Director/Quest/QuestDirectorGla30001";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(110081);
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A spar that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	finishGla300Bout(player, quest, actor);
end

function main()
end
