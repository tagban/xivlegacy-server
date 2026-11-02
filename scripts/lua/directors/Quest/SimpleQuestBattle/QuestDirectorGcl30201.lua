require ("global")
require ("modifiers")
require ("quests/gcl/gcl302")

-- Saving the Stead Instead's fight at the old kobold den north and east of
-- Bloodshore (content SimpleContentGcl30201). The entry kick raises the
-- loading veil even in place, so it is lifted and the kick closed. Once the
-- kobolds fall you are set down among the Executioners, to report to Hyllfyr.

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorGcl30201";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(111418);

	-- questBaseRewardSeting is the client's call that lifts the veil.
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A duty that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	quest:StartSequence(SEQ_010);
	attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
	player:EndEvent();
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	GetWorldManager():DoZoneChange(player, DEN[1], nil, 0, 15,
		DEN[2], DEN[3], DEN[4], DEN[5]);
end

function main()
end
