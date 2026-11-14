require ("global")
require ("quests/spl/allsaints")

-- Yvane (Ul'dah), an Adventurers' Guild runner for All Saints' Wake (Spl0i2), when
-- no quest of the player's answers for them: the cookie exchange.
function onEventStarted(player, npc)
	allSaintsRunnerTalk(player, npc);
end
