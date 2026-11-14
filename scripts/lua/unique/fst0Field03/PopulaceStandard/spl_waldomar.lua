require ("global")
require ("quests/spl/starlight")

-- Waldomar in Hyrstmill (Starlight Celebration), when no quest of the
-- player's answers for him.
function onEventStarted(player, npc)
	if (player:IsQuestCompleted(SPL0I4_ID)) then
		callClientFunction(player, "delegateEvent", player, GetStaticActor("Spl0i4"), "processEventClearAfter");
	elseif (player:IsQuestCompleted(SPL0I3_ID)) then
		callClientFunction(player, "delegateEvent", player, GetStaticActor("Spl0i3"), "processEventXmas04Afterdefo");
	else
		callClientFunction(player, "delegateEvent", player, GetStaticActor("Spl0i3"), "processEventXmas04defo");
	end
	player:EndEvent();
end
