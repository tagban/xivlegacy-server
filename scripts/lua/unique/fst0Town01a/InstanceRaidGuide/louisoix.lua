require ("global")

function init(npc)
	return false, false, 0, 0, 0x1eb, 0x2;
end

function onEventStarted(player, npc)
    defaultFst = GetStaticActor("DftFst");
	callClientFunction(player, "delegateEvent", player, defaultFst, "defaultTalkLouisoix_001", nil, nil, nil);
	player:EndEvent();
end