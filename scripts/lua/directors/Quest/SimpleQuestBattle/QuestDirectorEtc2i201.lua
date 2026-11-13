require ("global")
require ("modifiers")
require ("quests/etc/etc2i2")

-- Blood Price (Etc2i2): the Lambs of Dalamud at Gwyr-Aen, two Lunatic Lambs
-- at a time and then the Lunatic Shepherd (content SimpleContentEtc2i201).
-- It waits for the content's own win signal: the server's battleComplete
-- would fire between the waves.

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorEtc2i201";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(110708);
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	waitForSignal("allyFightWon");
	wait(2);
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	winEtc2i2Fight(player, quest);
end

function main()
end
