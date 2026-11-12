require ("global")
require ("modifiers")
require ("quests/man/man2l0")

-- Never the Twain Shall Meet's deck duty (content SimpleContentMan2l001).
-- The client's QuestDirectorMan2l001 is an empty subclass of
-- QuestDirectorBaseClass; the scenes come from the quest. The entry kick
-- raises the loading veil, so it is lifted and the kick closed; when the
-- quarrel is over the deck scenes play and the player goes back to Limsa.

function init()
	return "/Director/Quest/QuestDirectorMan2l001";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(110004);
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A loss ends the content, which purges this coroutine.
	waitForSignal("duelOver");
	wait(2);
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	finishMan2l0Duel(player, quest);
end

function main()
end
