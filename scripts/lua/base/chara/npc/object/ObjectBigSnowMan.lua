require ("global")
require ("quests/spl/starlight")

--[[

ObjectBigSnowMan: Father Frost, the giant of snow in Hyrstmill during the
Starlight Celebration. While Spl0i3 has the player throwing snowballs the
quest answers for him; otherwise he's just an effigy.

]]

function init(npc)
	return false, false, 0, 0;
end

function onEventStarted(player, npc, triggerName)
	local quest = GetStaticActor("Spl0i3");
	if (triggerName == "emoteDefault1") then
		-- a snowball with none to throw
		callClientFunction(player, "delegateEvent", player, quest, "processEventSnowMandefo2");
	else
		callClientFunction(player, "delegateEvent", player, quest, "processEventSnowMandefo");
	end
	player:EndEvent();
end
