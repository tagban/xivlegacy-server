require ("global")
require ("modifiers")
require ("quests/com/com0l1")

-- The Price of Integrity's familiar on the cliffs east of Wineport (content
-- SimpleContentCom0l101). The duty is entered in place, but the entry kick
-- still raises the loading veil, so it is lifted and the kick closed. Once
-- the familiar falls, Y'shtola finds you (processEvent_030) and the quest
-- sends you back to Walcher.

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorCom0l101";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(111401);

	-- The entry kick raises the Now Loading veil even in place (the screen
	-- dims, a spinner turns, and no command or talk starts until it's
	-- lifted); questBaseRewardSeting is the client's call that lifts it.
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A duty that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	-- processEvent_030 fades in after a warp: the warp out below is it.
	callClientFunction(player, "delegateEvent", player, quest, "processEvent_030");
	quest:StartSequence(SEQ_030);
	player:EndEvent();
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	GetWorldManager():DoZoneChange(player, CAMP_OUTSIDE[1], nil, 0, 15,
		CAMP_OUTSIDE[2], CAMP_OUTSIDE[3], CAMP_OUTSIDE[4], CAMP_OUTSIDE[5]);
end

function main()
end
