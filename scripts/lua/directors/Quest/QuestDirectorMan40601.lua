require ("global")
require ("modifiers")
require ("quests/man/man406")

-- Futures Perfect's duty (content SimpleContentMan40601). The duty is
-- entered in place, but the entry kick still raises the loading veil, so
-- it is lifted and the kick closed. Once the patrol is beaten: the
-- airship, the legatus and the Scions (man40630, MAN40635, man40645, which
-- end on an after-warp fade), and you are moved into the children's cave
-- in this same duty (a same-map content warp, spawnType 16). The cave's
-- way out is the quest's (onPush, CAVE_EXIT_TRIGGER), which ends the duty.

CAVE_ENTRY = { 300.0, 55.1, -800.0, 3.14 };

function init()
	return "/Director/Quest/QuestDirectorMan40601";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(110019);

	-- questBaseRewardSeting is the client's call that lifts the veil.
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	-- A duty that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	callClientFunction(player, "delegateEvent", player, quest, "pE30", companionArgs(player));
	quest:StartSequence(SEQ_045);
	player:EndEvent();
	GetWorldManager():DoZoneChangeContent(player, player:GetZone(),
		CAVE_ENTRY[1], CAVE_ENTRY[2], CAVE_ENTRY[3], CAVE_ENTRY[4], 16);
end

function main()
end
