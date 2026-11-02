require ("global")
require ("modifiers")
require ("quests/cnj/cnj200")

-- Cnj200's coywolf fight (content SimpleContentCnj20001). The entry kick
-- raises the loading veil, so it is lifted and the kick closed; a win is
-- handled by finishCnj200Fight in quests/cnj/cnj200.lua.

function init()
	return "/Director/Quest/QuestDirectorCnj20001";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(110260);
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A fight that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	finishCnj200Fight(player, quest, actor);
end

function main()
end
