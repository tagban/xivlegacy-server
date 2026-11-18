-- Monster Points vendor (scripts/lua/monsterpoints.lua).
require("monsterpoints")

function init(npc)
    return false, false, 0, 0;
end

function onEventStarted(player, npc, triggerName)
    MonsterPointsVendor(player, npc, "qiqirn");
end
