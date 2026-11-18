require ("global")
require ("modifiers")
require ("quests/pgl/pgl300")

-- Pgl300's hold (content SimpleContentPgl30001). The entry kick raises the
-- loading veil, so it is lifted and the kick closed; a win is handled by
-- finishPgl300Hold in quests/pgl/pgl300.lua.

function init()
	return "/Director/Quest/QuestDirectorPgl30001";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(110061);
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A fight that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	finishPgl300Hold(player, quest, actor);
end

function main()
end
