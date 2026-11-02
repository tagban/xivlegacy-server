require ("global")
require ("modifiers")
require ("quests/lnc/lnc200")

-- Lnc200's chigoe cull (content SimpleContentLnc20001). The entry kick
-- raises the loading veil, so it is lifted and the kick closed; a win is
-- handled by finishLnc200Cull in quests/lnc/lnc200.lua.

function init()
	return "/Director/Quest/QuestDirectorLnc20001";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(110180);
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A cull that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	finishLnc200Cull(player, quest, actor);
end

function main()
end
