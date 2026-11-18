require ("global")
require ("modifiers")
require ("quests/com/com0u6")

-- Know Your Enemy's fight with Charledore at the ferry docks of Vesper Bay
-- (content SimpleContentCom0u601). The duty is entered in place, but the
-- entry kick still raises the loading veil, so it is lifted and the kick
-- closed. Once he falls, his last words and Cid's arrival play (com0u510,
-- which ends waiting on a warp) and the quest sends you back to the airship
-- landing, where Cid waits.

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorCom0u601";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(111806);

	-- The entry kick raises the Now Loading veil even in place (the screen
	-- dims, a spinner turns, and no command or talk starts until it's
	-- lifted); questBaseRewardSeting is the client's call that lifts it.
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A duty that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	callClientFunction(player, "delegateEvent", player, quest, "processEvent_005_03", 0);
	quest:StartSequence(SEQ_010);
	player:EndEvent();
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	GetWorldManager():DoZoneChange(player, LANDING[1], nil, 0, 15,
		LANDING[2], LANDING[3], LANDING[4], LANDING[5]);
end

function main()
end
