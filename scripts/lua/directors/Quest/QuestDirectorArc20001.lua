require ("global")
require ("modifiers")
require ("quests/arc/arc200")

-- Arc200's Ixal fight (content SimpleContentArc20001). The entry kick
-- raises the loading veil, so it is lifted and the kick closed; a win is
-- handled by finishArc200Fight in quests/arc/arc200.lua.

function init()
	return "/Director/Quest/QuestDirectorArc20001";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(110160);
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A fight that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	finishArc200Fight(player, quest, actor);
end

function main()
end
