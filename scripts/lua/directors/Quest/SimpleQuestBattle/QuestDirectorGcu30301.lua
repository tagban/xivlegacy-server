require ("global")
require ("modifiers")
require ("quests/gcu/gcu303")

-- A Weaver and a Mummer's skirmish on the mesa northeast of Nophica's Wells
-- (content SimpleContentGcu30301). The entry kick raises the loading veil
-- even in place, so it is lifted and the kick closed. Once the scouts fall
-- you are set down at the mesa's foot with word for Cahernaut.

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorGcu30301";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(111819);

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
	GetWorldManager():DoZoneChange(player, MESA_FOOT[1], nil, 0, 15,
		MESA_FOOT[2], MESA_FOOT[3], MESA_FOOT[4], MESA_FOOT[5]);
end

function main()
end
