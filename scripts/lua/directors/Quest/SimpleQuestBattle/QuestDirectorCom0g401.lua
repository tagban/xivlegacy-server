require ("global")
require ("modifiers")
require ("quests/com/com0g4")

-- The Mail Must Get Through: the defense of the conjurers' rite northwest of
-- Gridania (content SimpleContentCom0g401). The duty is entered in place, but
-- the entry kick still raises the loading veil, so it is lifted and the kick
-- closed. Once the imperials fall, one of them yields an enciphered letter
-- and the quest sends you back to Fulke.

function init()
	return "/Director/Quest/SimpleQuestBattle/QuestDirectorCom0g401";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(111604);

	-- The entry kick raises the Now Loading veil even in place (the screen
	-- dims, a spinner turns, and no command or talk starts until it's
	-- lifted); questBaseRewardSeting is the client's call that lifts it.
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A duty that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(IMPERIAL_LETTER, 1, 1);
	quest:StartSequence(SEQ_010);
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	GetWorldManager():DoZoneChange(player, RITE_GROUND[1], nil, 0, 15,
		RITE_GROUND[2], RITE_GROUND[3], RITE_GROUND[4], RITE_GROUND[5]);
end

function main()
end
