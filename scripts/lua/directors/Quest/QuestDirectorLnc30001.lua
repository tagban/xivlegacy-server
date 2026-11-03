require ("global")
require ("modifiers")
require ("quests/lnc/lnc300")

-- Lnc300's caravan fight (content SimpleContentLnc30001). The entry kick
-- raises the loading veil, so it is lifted and the kick closed; a win is
-- handled by finishLnc300Fight in quests/lnc/lnc300.lua.

function init()
	return "/Director/Quest/QuestDirectorLnc30001";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(110181);
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A fight that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	finishLnc300Fight(player, quest, actor);
end

function main()
end
