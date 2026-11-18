require ("dungeon")

-- !dungeon <name> / !dungeon leave (processor/dungeon.rs calls these).

function enterTotorak(player) enterDungeon(player, "totorak") end
function enterDzemael(player) enterDungeon(player, "dzemael") end
function enterAurum(player) enterDungeon(player, "aurum") end
function enterCutters(player) enterDungeon(player, "cutters") end
-- The primal and raid battles (no quest needed), for testing their bosses.
function enterEmbers(player) enterDungeon(player, "embers") end
function enterEmbersHard(player) enterDungeon(player, "embers_hard") end
function enterHowling(player) enterDungeon(player, "howling") end
function enterHowlingHard(player) enterDungeon(player, "howling_hard") end
function enterThornmarch(player) enterDungeon(player, "thornmarch") end
function enterCastrum(player) enterDungeon(player, "castrum") end
function enterRivenroad(player) enterDungeon(player, "rivenroad") end
function enterRivenroadHard(player) enterDungeon(player, "rivenroad_hard") end
function leave(player) leaveDungeon(player) end
