require ("global")
require ("modifiers")
require ("quests/com/com0l6")

-- Ceruleum Shock's riot at Vesper Bay (content SimpleContentCom0l601). The
-- duty is entered in place, but the entry kick still raises the loading veil,
-- so it is lifted and the kick closed. Once the Flames fall the quest sends
-- you to Lvfrid, waiting on the docks.

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorCom0l601";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(111406);

	-- The entry kick raises the Now Loading veil even in place (the screen
	-- dims, a spinner turns, and no command or talk starts until it's
	-- lifted); questBaseRewardSeting is the client's call that lifts it.
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A duty that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	quest:StartSequence(SEQ_005);
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	GetWorldManager():DoZoneChange(player, VESPER_BAY_DOCKS[1], nil, 0, 15,
		VESPER_BAY_DOCKS[2], VESPER_BAY_DOCKS[3], VESPER_BAY_DOCKS[4], VESPER_BAY_DOCKS[5]);
end

function main()
end
