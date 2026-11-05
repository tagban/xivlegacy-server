require ("global")
require ("modifiers")
require ("quests/man/man406")

-- Futures Perfect's duties, both run by this director class (the client
-- has no other content director for the quest):
--
-- SimpleContentMan40601, the patrol fight, entered in place. The entry
-- kick still raises the loading veil, so it is lifted and the kick
-- closed. Once the patrol is beaten: the airship, the legatus and the
-- Scions (man40630, MAN40635, man40645, which end on an after-warp fade),
-- SEQ_045, and the move into the children's cave. A director has no
-- handle on the content area it runs in, so the cave is a second duty
-- (SimpleContentMan40602): the fight is finished and you are moved into
-- the new one.
--
-- SimpleContentMan40602, the cave: its director only lifts the veil left
-- by pE30. The cave's way out is the quest's (onPush, CAVE_EXIT_TRIGGER),
-- which ends the duty.

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
	if (quest:GetSequence() == SEQ_045) then
		return; -- the cave
	end

	-- A duty that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(2);
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	callClientFunction(player, "delegateEvent", player, quest, "pE30", companionArgs(player));
	quest:StartSequence(SEQ_045);
	startCaveContent(player);
end

function startCaveContent(player)
	player:GetZone():ContentFinished();
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Man40602", "SimpleContentMan40602", "Quest/QuestDirectorMan40601");
	if (contentArea == nil) then
		player:EndEvent();
		return;
	end
	local director = contentArea:GetContentDirector();
	player:AddDirector(director);
	director:StartDirector(false);
	player:KickEvent(director, "noticeEvent", true);
	player:SetLoginDirector(director);
	player:EndEvent();
	GetWorldManager():DoZoneChangeContent(player, contentArea,
		CAVE_ENTRY[1], CAVE_ENTRY[2], CAVE_ENTRY[3], CAVE_ENTRY[4], 16);
end

function main()
end
