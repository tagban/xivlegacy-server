require ("global")
require ("modifiers")
require ("quests/man/man308")

-- Lord Errant's summoning in Paglth'an (content SimpleContentMan30801). The
-- duty is entered in place, but the entry kick still raises the loading
-- veil, so it is lifted and the kick closed. Once the captives and the
-- Amalj'aa are beaten, Ifrit questions you (pE60) and has you thrown out at
-- the gates (pE80), and the quest sends you back to the Waking Sands.

function init()
	return "/Director/Quest/QuestDirectorMan30801";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(110017);

	-- questBaseRewardSeting is the client's call that lifts the veil.
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A duty that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	callClientFunction(player, "delegateEvent", player, quest, "pE60", companionArgs(player));
	callClientFunction(player, "delegateEvent", player, quest, "pE80", companionArgs(player));
	quest:StartSequence(SEQ_080);
	player:EndEvent();
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	warpTo(player, PAGLTHAN_OUTSIDE);
end

function main()
end
