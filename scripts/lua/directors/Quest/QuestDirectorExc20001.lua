require ("global")
require ("modifiers")
require ("quests/exc/exc200")

-- Exc200's lemming hunt (content SimpleContentExc20001). The entry kick
-- raises the loading veil, so it is lifted and the kick closed; a win is
-- handled by finishExc200Hunt in quests/exc/exc200.lua.

function init()
	return "/Director/Quest/QuestDirectorExc20001";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(110100);
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A hunt that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	finishExc200Hunt(player, quest, actor);
end

function main()
end
