require ("global")
require ("modifiers")
require ("quests/com/com0l4")

-- Engineering Victory's ambush in the canyon (content SimpleContentCom0l401).
-- The duty is entered in place, but the entry kick still raises the loading
-- veil, so it is lifted and the kick closed. Once the fleeing imperials fall,
-- one of them yields a magitek transceiver and the quest sends you back to
-- Guincum.

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorCom0l401";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(111404);

	-- The entry kick raises the Now Loading veil even in place (the screen
	-- dims, a spinner turns, and no command or talk starts until it's
	-- lifted); questBaseRewardSeting is the client's call that lifts it.
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A duty that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(MAGITEK_TRANSCEIVER, 1, 1);
	quest:StartSequence(SEQ_010);
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	GetWorldManager():DoZoneChange(player, CANYON_FLOOR[1], nil, 0, 15,
		CANYON_FLOOR[2], CANYON_FLOOR[3], CANYON_FLOOR[4], CANYON_FLOOR[5]);
end

function main()
end
