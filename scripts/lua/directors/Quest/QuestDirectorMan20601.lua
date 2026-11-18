require ("global")
require ("modifiers")
require ("quests/man/man206")

-- Together We Stand's Moonspore Grove escort (content SimpleContentMan20601,
-- run by escort.lua). The client's QuestDirectorMan20601 is an empty subclass
-- of QuestDirectorBaseClass, like all its quest directors; the scenes come
-- from the quest itself.
--
-- Beat order follows the opening escorts' directors (QuestDirectorMan0g101),
-- except for the opening: the duty is entered in place (no warp), and the
-- entry kick's loading veil is lifted with questBaseRewardSeting before the
-- kick is closed. Each leg's arrival signal then plays its scenes.

function init()
	return "/Director/Quest/QuestDirectorMan20601";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(110014);

	-- The entry kick raises the Now Loading veil even in place (the screen
	-- dims, a spinner turns, and no command or talk starts until it's
	-- lifted); questBaseRewardSeting is the client's call that lifts it.
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	-- Close the entry kick; the escort's own loop takes it from here.
	player:EndEvent();

	-- The grove: the podlings, and one entrusted to you.
	-- A failed duty's ContentFinished purges this coroutine, so a signal
	-- only ever arrives from a real arrival.
	waitForSignal("groveReached");
	wait(2);
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	callClientFunction(player, "delegateEvent", player, quest, "processEvent016");
	callClientFunction(player, "delegateEvent", player, quest, "pE20", player:GetSNpcNickname(), player:GetSNpcSkin(), player:GetSNpcPersonality(), player:GetSNpcCoordinate(), player:GetInitialTown());
	quest:StartSequence(SEQ_025);
	player:EndEvent();

	-- Back at the camp with the podling.
	waitForSignal("campReached");
	wait(2);
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	-- pE30 fades in after a warp: the warp out below is it.
	callClientFunction(player, "delegateEvent", player, quest, "pE30", player:GetSNpcNickname(), player:GetSNpcSkin(), player:GetSNpcPersonality(), player:GetSNpcCoordinate(), player:GetInitialTown());
	quest:StartSequence(SEQ_030);
	-- "You are no longer bound by duty." is the client's own, as the content
	-- group comes down.
	player:EndEvent();
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	GetWorldManager():DoZoneChange(player, NINE_IVIES_OUTSIDE[1], nil, 0, 15,
		NINE_IVIES_OUTSIDE[2], NINE_IVIES_OUTSIDE[3], NINE_IVIES_OUTSIDE[4], NINE_IVIES_OUTSIDE[5]);
end

function main()
end
