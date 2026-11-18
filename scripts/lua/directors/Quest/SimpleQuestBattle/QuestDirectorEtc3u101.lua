require ("global")
require ("modifiers")
require ("quests/etc/etc3u1")

-- Quid Pro Quo (Etc3u1): four Unsavory Characters at the airship wreck, two
-- at a time (content SimpleContentEtc3u101). It waits for the content's own
-- win signal: the server's battleComplete would fire between the pairs.

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorEtc3u101";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(110726);
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	waitForSignal("allyFightWon");
	wait(2);
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	winEtc3u1Fight(player, quest);
end

function main()
end
