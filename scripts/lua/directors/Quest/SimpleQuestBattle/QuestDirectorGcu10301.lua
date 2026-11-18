require ("global")
require ("modifiers")
require ("quests/gcu/gcu103")

-- Careless Whispers' fight west of Camp Horizon (content
-- SimpleContentGcu10301). The duty is entered in place, but the entry kick
-- still raises the loading veil, so it is lifted and the kick closed. Once
-- the juggernaut falls you are set down among the wounded Flames, whose
-- fallen sergeant sends you on to the ferry docks.

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorGcu10301";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(111829);

	-- The entry kick raises the Now Loading veil even in place;
	-- questBaseRewardSeting is the client's call that lifts it.
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A duty that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	quest:StartSequence(SEQ_015);
	player:EndEvent();
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	GetWorldManager():DoZoneChange(player, BATTLEFIELD_EDGE[1], nil, 0, 15,
		BATTLEFIELD_EDGE[2], BATTLEFIELD_EDGE[3], BATTLEFIELD_EDGE[4], BATTLEFIELD_EDGE[5]);
end

function main()
end
