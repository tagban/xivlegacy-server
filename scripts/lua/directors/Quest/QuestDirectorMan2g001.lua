require ("global")
require ("modifiers")
require ("quests/man/man2g0")

-- Beckon of the Elementals' battle (content SimpleContentMan2g001). The
-- client's QuestDirectorMan2g001 is an empty subclass of
-- QuestDirectorBaseClass. The entry kick raises the loading veil, so it is
-- lifted and the kick closed; a win sends the player back to the guild.

function init()
	return "/Director/Quest/QuestDirectorMan2g001";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(110008);
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A loss ends the content, which purges this coroutine.
	waitForSignal("allyFightWon");
	wait(2);
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	finishMan2g0Fight(player, quest);
end

function main()
end
