require ("global")
require ("modifiers")
require ("quests/arc/arc300")

-- Arc300's heretic ambush (content SimpleContentArc30001). The entry kick
-- raises the loading veil, so it is lifted and the kick closed; a win is
-- handled by finishArc300Fight in quests/arc/arc300.lua.

function init()
	return "/Director/Quest/QuestDirectorArc30001";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(110161);
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A fight that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	finishArc300Fight(player, quest, actor);
end

function main()
end
