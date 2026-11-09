--[[

ChangeJobCommand Script

Sent by the soul crystal slot in the gear window (command 12017): mode 1
takes up the job of the player's current class, mode 2 goes back to the
class. The client offers it only for a soul crystal the player holds
(job items, package 101) that matches their class; the server checks again.

--]]

function onEventStarted(player, actor, triggerName, mode)
	if (mode == 1 or mode == 2) then
		player:ChangeJob(mode);
	end
	player:EndEvent();
end
