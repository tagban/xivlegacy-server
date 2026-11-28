--[[

PopulacePassiveGLPublisher Script

Functions:

askOfferPack() - Show Classes
askOfferRank() - Show Ranks
askOfferQuest(player)
confirmOffer(nil, questId)
confirmMaxOffer()
talkOfferWelcome(actor, leveAllowances)
talkOfferDecide()
talkOfferMaxOver()
selectDiscardGuildleve(player)
confirmJournal()
askDiscardGuildleve()
confirmDiscardGuildleve(nil, questId)
askRetryRegionalleve(questId, leveAllowances)
finishTalkTurn()

--]]

require ("global")

function init(npc)
	return false, false, 0, 0;	
end

function onEventStarted(player, npc)
	-- The leve allowances left (map-server/src/leve/allowance.rs): local
	-- leves share the pool, though they can't be taken here yet.
	callClientFunction(player, "talkOfferWelcome", player, player:GetLeveAllowances());
	player:EndEvent();
end

function onEventUpdate(player, npc, step, menuOptionSelected, lsName, lsCrest)
	--callClientFunction(player, "askOfferQuest", player, 1000);
	
end