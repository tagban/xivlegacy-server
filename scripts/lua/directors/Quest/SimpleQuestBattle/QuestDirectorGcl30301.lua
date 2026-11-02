require ("global")
require ("modifiers")
require ("quests/gcl/gcl303")

-- It's a Piece of Cake to Bake a Poison Cake's scuffle in Cedarwood with
-- Kikkiroon Irongut (content SimpleContentGcl30301). The entry kick raises
-- the loading veil, so it is lifted and the kick closed. Once the Qiqirn
-- yields you are set down in the clearing, where he stands chastened and
-- Storm Commander Rhiki looks on.

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorGcl30301";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(111419);

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
	GetWorldManager():DoZoneChange(player, CEDARWOOD_FOOT[1], nil, 0, 15,
		CEDARWOOD_FOOT[2], CEDARWOOD_FOOT[3], CEDARWOOD_FOOT[4], CEDARWOOD_FOOT[5]);
end

function main()
end
