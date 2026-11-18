require ("global")
require ("modifiers")
require ("dungeon")

-- The Grand Companies' Garuda battle in the Howling Eye (In for Garuda
-- Wakening, Gc?104; content SimpleContentHowlingEye). The client's director
-- plays Garuda's descent and opens the battle timer from startEvent. Once
-- Garuda falls, her end and Nael van Darnus's words play (GC010430,
-- GC010440) and you are back in Feathergorge.

IN_FOR_GARUDA_WAKENING = { 111430, 111630, 111830 };

CONTENT_ID		= 12;		-- the Howling Eye in the client's raid list (timer widget)
TIME_LIMIT		= 30;		-- minutes, as the briefing tells it

local function garudaQuest(player)
	for _, id in ipairs(IN_FOR_GARUDA_WAKENING) do
		-- GetQuest hands back a quest for any id, held or not
		if player:HasQuest(id) then return player:GetQuest(id) end
	end
end

function init()
	return "/Director/InstanceRaid/InstanceRaidLesserGaruda";
end

function onEventStarted(player, actor, triggerName)
	local now = os.time();
	-- The trailing argument has the client's processStartEvent play the
	-- primal's descent before the timer opens.
	callClientFunction(player, "startEvent", "none", 0, 0, CONTENT_ID, now, now + TIME_LIMIT * 60, 0, 1);
	player:EndEvent();

	-- A battle that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(3);
	local quest = garudaQuest(player);
	if quest ~= nil then
		quest:StartSequence(30);	-- SEQ_030 in quests/gc/gc104.lua
	end
	-- A fresh notice event to play them in; no owner (nil) has the director
	-- play them as its own.
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	-- exitCutScene fades out, plays, and fades back in only after the next
	-- warp, so only the last scene goes through it: two in a row leave the
	-- screen on Now Loading after the warp out.
	callClientFunction(player, "executeCutScene", "GC010430", nil, false);
	callClientFunction(player, "exitCutScene", "GC010440", nil, true);
	player:EndEvent();
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	leaveDungeon(player);
end

function main()
end
