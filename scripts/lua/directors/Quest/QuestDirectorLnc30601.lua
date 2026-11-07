require ("global")
require ("modifiers")
require ("quests/lnc/lnc306")

-- Lnc306's fight with the elemental (content
-- SimpleContentLnc30601). The entry kick raises the loading veil, so it is
-- lifted and the kick closed; a win is handled by finishLnc306Fight in
-- quests/lnc/lnc306.lua.

function init()
	return "/Director/Quest/QuestDirectorLnc30601";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(110182);
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A fight that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	finishLnc306Fight(player, quest, actor);
end

function main()
end
