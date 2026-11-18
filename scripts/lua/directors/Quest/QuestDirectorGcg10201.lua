require ("global")
require ("modifiers")
require ("quests/gcg/gcg102")

-- Two Vans are Better than One's fight at the Toto-Moy Battlewarrens
-- (content SimpleContentGcg10201). The duty is entered in place, but the
-- entry kick still raises the loading veil, so it is lifted and the kick
-- closed. Once the Garleans fall you are set back down among the Yellow
-- Serpents; the Echo's cut scene plays later, from Pfrymloef.

function init()
	return "/Director/Quest/QuestDirectorGcg10201";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(111627);

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
	GetWorldManager():DoZoneChange(player, BATTLEWARRENS[1], nil, 0, 15,
		BATTLEWARRENS[2], BATTLEWARRENS[3], BATTLEWARRENS[4], BATTLEWARRENS[5]);
end

function main()
end
