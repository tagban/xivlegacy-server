require ("global")

--[[

Tataru (present day, the Quicksand): Selecting a Different Path Companion (Trl0l3, 110144).

Once the player has finished Man200 (the first companion pick), talking to Tataru
picks again. Trl0l3's client script has only the lines around the pick: the
opening (processSnpcReselectEvent001), the naming (processSnpcReName) and the
close (processSnpcReselectEvent002). The class menu itself is Man200's
processSnpcSelect, as in the first pick. Choosing Quit keeps the companion.

Tataru standing in the Quicksand is our choice: in 1.23b she is only met in the
Waking Sands, which opens only inside the main scenario.
]]

MAN200 = 110013;

function onEventStarted(player, npc)
	if (not player:IsQuestCompleted(MAN200)) then
		player:EndEvent();
		return;
	end

	local trl = GetStaticActor("Trl0l3");
	local man200 = GetStaticActor("Man200");
	if (trl == nil or man200 == nil) then
		player:EndEvent();
		return;
	end

	callClientFunction(player, "delegateEvent", player, trl, "processSnpcReselectEvent001", player, npc);
	local classId, personality = callClientFunction(player, "delegateEvent", player, man200, "processSnpcSelect", player, npc);
	if (classId == nil or personality == nil or classId == -1 or personality == -1) then
		player:EndEvent();
		return;
	end

	local name = callClientFunction(player, "delegateEvent", player, trl, "processSnpcReName", player, npc);
	if (type(name) ~= "string" or name == "") then
		name = player:GetSNpcNickname();
	end
	player:SetSNpc(name, classId, personality);
	callClientFunction(player, "delegateEvent", player, trl, "processSnpcReselectEvent002", player, npc);
	player:EndEvent();
end
