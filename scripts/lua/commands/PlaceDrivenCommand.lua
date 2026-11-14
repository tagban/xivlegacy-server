--[[

PlaceDrivenCommand Script

Runs when the player picks an Interaction Menu entry that an actor's push
circle offered (npcWork.pushCommand). The client sends the push command id
and the actor that offered it.

Gathering points offer push commands 20001-20007 (Mine, Log, Fish, ...).
For those the server kicks "commandJudgeMode" on the matching harvest
command (Mine = 22002, ...): the client runs that command on the targeted
point and its EventStart reaches DummyCommand.lua. The server sends a
kick on a command actor with event type 0, which puts the client in
judge mode so the gathering window can open. The commandRequest is
ended right away; the judge event carries on by itself. Kicking the
point itself crashes the 1.23b client (a fatal error in the client's
event start). Every other actor gets its own "pushCommand" event.

--]]
require("global")

-- Push command offered by a gathering point (gamedata_actor_pushcommand,
-- classes 1200052-1200057) -> the harvest command it runs.
GATHER_PUSH_COMMANDS = {[20001] = 22002, [20002] = 22003, [20003] = 22004,
	[20005] = 22006, [20006] = 22007, [20007] = 22008};

function onEventStarted(player, command, triggerName, pushCommand, unk1, unk2, unk3, ownerActorId, unk4, unk5, unk6, unk7)
	if (ownerActorId == nil or ownerActorId == 0) then
		player:EndEvent();
		return;
	end

	local harvestCommand = GATHER_PUSH_COMMANDS[pushCommand];
	if (harvestCommand ~= nil) then
		player:KickEvent(0xA0F00000 + harvestCommand, "commandJudgeMode", "commandJudgeMode");
		player:EndEvent();
	else
		player:KickEvent(ownerActorId, "pushCommand", "pushCommand");
	end
end
