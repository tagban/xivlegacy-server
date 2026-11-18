require ("global")
require ("modifiers")
require ("quests/com/com0u5")

-- Burning Man's ambush at the ferry docks of Vesper Bay (content
-- SimpleContentCom0u501). The duty is entered in place, but the entry kick
-- still raises the loading veil, so it is lifted and the kick closed. Once
-- the pirates fall the quest sends you to Thancred, waiting on the docks.

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorCom0u501";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(111805);

	-- The entry kick raises the Now Loading veil even in place (the screen
	-- dims, a spinner turns, and no command or talk starts until it's
	-- lifted); questBaseRewardSeting is the client's call that lifts it.
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A duty that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	quest:StartSequence(SEQ_010);
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	GetWorldManager():DoZoneChange(player, FERRY_DOCKS_ROAD[1], nil, 0, 15,
		FERRY_DOCKS_ROAD[2], FERRY_DOCKS_ROAD[3], FERRY_DOCKS_ROAD[4], FERRY_DOCKS_ROAD[5]);
end

function main()
end
