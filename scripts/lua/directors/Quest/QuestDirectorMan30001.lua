require ("global")
require ("modifiers")
require ("quests/man/man300")

-- Toll of the Warden's summoning in the mesa cave (content
-- SimpleContentMan30001). The duty is entered in place, but the entry kick
-- still raises the loading veil, so it is lifted and the kick closed. Once
-- the tribes are beaten, the Ascian appears and scatters them (pE50), and the
-- quest sends you back to the Consortium.

function init()
	return "/Director/Quest/QuestDirectorMan30001";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(110015);

	-- The entry kick raises the Now Loading veil even in place (the screen
	-- dims, a spinner turns, and no command or talk starts until it's
	-- lifted); questBaseRewardSeting is the client's call that lifts it.
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A duty that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	-- pE50 fades in after a warp: the warp out below is it.
	callClientFunction(player, "delegateEvent", player, quest, "pE50", companionArgs(player));
	quest:StartSequence(SEQ_050);
	player:EndEvent();
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	GetWorldManager():DoZoneChange(player, MESA_MOUTH[1], nil, 0, 15,
		MESA_MOUTH[2], MESA_MOUTH[3], MESA_MOUTH[4], MESA_MOUTH[5]);
end

function main()
end
