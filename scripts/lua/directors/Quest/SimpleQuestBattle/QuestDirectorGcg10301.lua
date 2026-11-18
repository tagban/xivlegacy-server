require ("global")
require ("modifiers")
require ("quests/gcg/gcg103")

-- Shadow of the Raven's ranging in the West Shroud (content
-- SimpleContentGcg10301). The duty is entered in place, but the entry kick
-- still raises the loading veil, so it is lifted and the kick closed. Once
-- the war machine falls the aftermath plays (gc01g320), the quest closes,
-- and you are set down on the ranging ground.

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorGcg10301";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(111629);

	-- The entry kick raises the Now Loading veil even in place;
	-- questBaseRewardSeting is the client's call that lifts it.
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A duty that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	finishGcg103(player, quest);
	player:EndEvent();
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	GetWorldManager():DoZoneChange(player, RANGING_GROUND[1], nil, 0, 15,
		RANGING_GROUND[2], RANGING_GROUND[3], RANGING_GROUND[4], RANGING_GROUND[5]);
end

function main()
end
