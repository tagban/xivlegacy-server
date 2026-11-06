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

--]]

-- Opens (or moves) the player's duty countdown: `seconds` left from now.
function ShowContentTimer(player, seconds, contentId)
	if (player == nil or seconds == nil or seconds <= 0) then
		return;
	end
	player:SendDataPacket("xlContentTimer", contentId or 0, os.time() + math.floor(seconds));
end
