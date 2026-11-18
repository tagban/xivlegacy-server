require ("global")
require ("modifiers")
require ("quests/gcu/gcu102")

-- Like Father, Like Son's fight at the cave north-west of Camp Black Brush
-- (content SimpleContentGcu10201). The duty is entered in place, but the
-- entry kick still raises the loading veil, so it is lifted and the kick
-- closed. Once the Garleans fall you are set back down at the cave, where
-- the survivor lies; the Echo's cut scene plays later, from him.

function init()
	return "/Director/Quest/QuestDirectorGcu10201";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(111827);

	-- The entry kick raises the Now Loading veil even in place;
	-- questBaseRewardSeting is the client's call that lifts it.
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A duty that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	quest:StartSequence(SEQ_010);
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	GetWorldManager():DoZoneChange(player, CAVE_EDGE[1], nil, 0, 15,
		CAVE_EDGE[2], CAVE_EDGE[3], CAVE_EDGE[4], CAVE_EDGE[5]);
end

function main()
end
