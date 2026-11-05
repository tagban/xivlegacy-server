require ("global")
require ("modifiers")
require ("quests/man/man402")

-- Of Men They Sing's bloodhounds (content SimpleContentMan40201). The duty
-- is entered in place, but the entry kick still raises the loading veil, so
-- it is lifted and the kick closed. Once the hounds are beaten, your
-- companion sees to the scout and sends you back to report (pE20), and you
-- are left at the ravine's edge.

function init()
	return "/Director/Quest/QuestDirectorMan40201";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(110018);

	-- questBaseRewardSeting is the client's call that lifts the veil.
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A duty that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	callClientFunction(player, "delegateEvent", player, quest, "pE20", companionArgs(player));
	quest:StartSequence(SEQ_020);
	player:EndEvent();
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	warpTo(player, SCOUT_RAVINE_EDGE);
end

function main()
end
