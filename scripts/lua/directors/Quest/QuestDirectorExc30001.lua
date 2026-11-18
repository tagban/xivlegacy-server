require ("global")
require ("quests/exc/exc300")

-- Exc300's den (content SimpleContentExc30001). The entry kick raises the
-- loading veil, so it is lifted and the kick closed; the papers are quest
-- talks in quests/exc/exc300.lua, which ends the content.

function init()
	return "/Director/Quest/QuestDirectorExc30001";
end

function onEventStarted(player, actor, triggerName)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(110101);
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();
end

function main()
end
