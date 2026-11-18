require ("global")
require ("modifiers")
require ("quests/thm/thm300")

-- Thm300's Ignis Fatuus fight (content SimpleContentThm30001). The entry kick
-- raises the loading veil, so it is lifted and the kick closed; a win is
-- handled by finishThm300Fight in quests/thm/thm300.lua.

function init()
	return "/Director/Quest/QuestDirectorThm30001";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(110241);
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A fight that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	finishThm300Fight(player, quest, actor);
end

function main()
end
