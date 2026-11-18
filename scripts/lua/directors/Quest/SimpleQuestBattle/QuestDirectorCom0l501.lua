require ("global")
require ("modifiers")
require ("quests/com/com0l5")

-- An Officer and a Wise Man's fight with the brigands tracking the Admiral
-- (content SimpleContentCom0l501). The duty is entered in place, but the
-- entry kick still raises the loading veil, so it is lifted and the kick
-- closed. Once the brigands fall, the fight's aftermath plays
-- (processEvent_010) and you step out on the clearing road, in sight of
-- Merlwyb.

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorCom0l501";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(111405);

	-- The entry kick raises the Now Loading veil even in place (the screen
	-- dims, a spinner turns, and no command or talk starts until it's
	-- lifted); questBaseRewardSeting is the client's call that lifts it.
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A duty that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	-- processEvent_010 (COM0l110) fades in after a warp: the warp out below is it.
	callClientFunction(player, "delegateEvent", player, quest, "processEvent_010");
	quest:StartSequence(SEQ_005);
	player:EndEvent();
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	GetWorldManager():DoZoneChange(player, CLEARING_ROAD[1], nil, 0, 15,
		CLEARING_ROAD[2], CLEARING_ROAD[3], CLEARING_ROAD[4], CLEARING_ROAD[5]);
end

function main()
end
