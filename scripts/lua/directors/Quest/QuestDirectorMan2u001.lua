require ("global")
require ("modifiers")
require ("quests/man/man2u0")

-- Calamity Cometh's minemite battle (content SimpleContentMan2u001). The
-- client's QuestDirectorMan2u001 is an empty subclass of
-- QuestDirectorBaseClass. The entry kick raises the loading veil, so it is
-- lifted and the kick closed; a win plays the closing scene.

function init()
	return "/Director/Quest/QuestDirectorMan2u001";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(110012);
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A loss ends the content, which purges this coroutine.
	waitForSignal("allyFightWon");
	wait(2);
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	finishMan2u0Fight(player, quest);
end

function main()
end
