--[[

A duty's time left, drawn on screen.

1.23b counts down on screen only in raids (the raid director opens the
desktop's RaidDungeonExecutionWidget). The XIVLegacy client teaches the
player script one more data packet that opens the same widget for any
duty:

    'xlContentTimer', contentId, finishTime   open it (finishTime in os.time() seconds)
    'xlContentTimer', 0, 0                    close it

A stock client ignores both. The map server closes the timer itself when
the content finishes (ContentFinished, on success, fail or logout), so a
duty only opens it.

contentId is a row of the client's content list, the widget's title.
0 shows no title.

The client won't build the widget while it is still building another one
(the duty's opening banner, the zone-in desktop), so a duty queues its
countdown with QueueContentTimer and calls UpdateContentTimer every tick:
the packet goes out a few seconds later.

--]]

-- Opens (or moves) the player's duty countdown: `seconds` left from now.
function ShowContentTimer(player, seconds, contentId)
	if (player == nil or seconds == nil or seconds <= 0) then
		return;
	end
	player:SendDataPacket("xlContentTimer", contentId or 0, os.time() + math.floor(seconds));
end

-- Ticks between QueueContentTimer and the packet (4 s at 2 ticks a second).
CONTENT_TIMER_DELAY_TICKS = 8;

-- Queues the countdown on a duty's state table; finishTick is the tick the
-- duty runs out.
function QueueContentTimer(state, tick, finishTick, contentId)
	state.contentTimer = { at = tick + CONTENT_TIMER_DELAY_TICKS, finish = finishTick, contentId = contentId };
end

-- Sends a queued countdown once its delay has passed.
function UpdateContentTimer(player, state, tick, ticksPerSecond)
	local t = state.contentTimer;
	if (t == nil or tick < t.at) then
		return;
	end
	state.contentTimer = nil;
	ShowContentTimer(player, (t.finish - tick) / ticksPerSecond, t.contentId);
end
