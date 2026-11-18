require ("global")
require ("modifiers")
require ("quests/gcl/gcl103")

-- Deus ex Machina's stand at Aleport (content SimpleContentGcl10301). The
-- duty is entered in place, but the entry kick still raises the loading veil,
-- so it is lifted and the kick closed. Once the magitek vanguard falls the
-- aftermath plays (gc01l320), the quest closes, and you are set down in the
-- hamlet.

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorGcl10301";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(111429);

	-- The entry kick raises the Now Loading veil even in place;
	-- questBaseRewardSeting is the client's call that lifts it.
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A duty that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	finishGcl103(player, quest);
	player:EndEvent();
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	GetWorldManager():DoZoneChange(player, ALEPORT_SQUARE[1], nil, 0, 15,
		ALEPORT_SQUARE[2], ALEPORT_SQUARE[3], ALEPORT_SQUARE[4], ALEPORT_SQUARE[5]);
end

function main()
end
