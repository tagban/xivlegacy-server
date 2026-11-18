require ("global")
require ("modifiers")
require ("quests/gcl/gcl102")

-- Alive's northern pass into Oakwood (content SimpleContentGcl10201). The
-- duty is entered in place, but the entry kick still raises the loading veil,
-- so it is lifted and the kick closed. Once the imperials fall, Gaius van
-- Baelsar's arrival at the crash site plays (gc01l210, which ends on a warp)
-- and you are set down there beside Cid.

function init()
	return "/Director/Quest/QuestDirectorGcl10201";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(111427);

	-- The entry kick raises the Now Loading veil even in place;
	-- questBaseRewardSeting is the client's call that lifts it.
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A duty that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	callClientFunction(player, "delegateEvent", player, quest, "processEventNQ");
	quest:StartSequence(SEQ_020);
	player:EndEvent();
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	GetWorldManager():DoZoneChange(player, CRASH_SITE[1], nil, 0, 15,
		CRASH_SITE[2], CRASH_SITE[3], CRASH_SITE[4], CRASH_SITE[5]);
end

function main()
end
