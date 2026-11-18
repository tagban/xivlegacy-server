require ("global")
require ("modifiers")
require ("dungeon")

-- The Grand Companies' Ifrit battle in the Bowl of Embers (It Kills with
-- Fire, Gc?101; content SimpleContentBowlOfEmbers). The client's director
-- plays Ifrit's descent (cut scene GC010105) and opens the battle timer from
-- startEvent. Once Ifrit falls, Nael van Darnus's appearance plays
-- (GC010110) and Louisoix takes you back to Apkallus Falls.

IT_KILLS_WITH_FIRE = { 111416, 111616, 111816 };

CONTENT_ID		= 4;		-- the Bowl of Embers in the client's raid list (timer widget)
TIME_LIMIT		= 30;		-- minutes, as the briefing tells it

local function ifritQuest(player)
	for _, id in ipairs(IT_KILLS_WITH_FIRE) do
		-- GetQuest hands back a quest for any id, held or not
		if player:HasQuest(id) then return player:GetQuest(id) end
	end
end

function init()
	return "/Director/InstanceRaid/InstanceRaidLesserIfrit";
end

function onEventStarted(player, actor, triggerName)
	local now = os.time();
	-- The trailing argument has the client's processStartEvent play Ifrit's
	-- descent (GC010105) before the timer opens.
	callClientFunction(player, "startEvent", "none", 0, 0, CONTENT_ID, now, now + TIME_LIMIT * 60, 0, 1);
	player:EndEvent();

	-- A battle that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(3);
	local quest = ifritQuest(player);
	if quest ~= nil then
		quest:StartSequence(50);	-- SEQ_050 in quests/gc/gc101.lua
	end
	-- A fresh notice event to play it in; no owner (nil) has the director
	-- play it as its own.
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	callClientFunction(player, "exitCutScene", "GC010110", nil, true);
	player:EndEvent();
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	leaveDungeon(player);
end

function main()
end
