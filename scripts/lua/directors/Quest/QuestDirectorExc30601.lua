require ("global")
require ("quests/exc/exc306")

-- Exc306's beating (content SimpleContentExc30601) and its alehold
-- (SimpleContentExc30603): the client has two directors for the quest, so
-- these share one. The entry kick raises the loading veil, so it is lifted
-- and the kick closed; the content and quest scripts do the rest.

function init()
	return "/Director/Quest/QuestDirectorExc30601";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(110102);
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();
end

function main()
end
