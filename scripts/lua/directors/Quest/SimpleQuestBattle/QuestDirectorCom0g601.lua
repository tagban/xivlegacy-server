require ("global")
require ("modifiers")
require ("quests/com/com0g6")

-- Appetite for Destruction's clearing west of Camp Nine Ivies (content
-- SimpleContentCom0g601). The duty is entered in place, but the entry kick
-- still raises the loading veil, so it is lifted and the kick closed. Once
-- the spiders fall, Cid's flare and Arthur's rage play (com0g510) and
-- the quest sends you back to Stillglade Fane.

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorCom0g601";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(111606);

	-- The entry kick raises the Now Loading veil even in place (the screen
	-- dims, a spinner turns, and no command or talk starts until it's
	-- lifted); questBaseRewardSeting is the client's call that lifts it.
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A duty that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	callClientFunction(player, "delegateEvent", player, quest, "processEventNq");
	quest:StartSequence(SEQ_020);
	player:EndEvent();
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	GetWorldManager():DoZoneChange(player, CLEARING_EDGE[1], nil, 0, 15,
		CLEARING_EDGE[2], CLEARING_EDGE[3], CLEARING_EDGE[4], CLEARING_EDGE[5]);
end

function main()
end
