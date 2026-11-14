--[[

Selecting a Different Path Companion (Trl0l3, 110144): picking the Path companion again
after Man200. "Active for all players at all times" in 1.0, so it is no journal quest here:
two Tataru overrides run it.

* Tataru in the Quicksand (unique/wil0Town01/.../tataru.lua, our placement) takes the
  player into the Waking Sands (zone 181, PrivateAreaMasterPast 0, where Man200's NPCs
  stand), so no held quest is needed to get in.
* Tataru there (man200_tataru.lua) plays the opening (processSnpcReselectEvent001,
  Trl0l3 lines 1-3), Man200's re-pick menu (processSnpcReselect: the class menu, the
  companion cutscene, which only plays in the Waking Sands, then the paperwork line and
  the confirm; unlike processSnpcSelect it skips Tataru's first-pick introduction and
  the linkpearl lines), the naming (processSnpcReName, line 11) and the close
  (processSnpcReselectEvent002, line 12), then back to the Quicksand. Quit in the menu
  keeps the companion and also goes back.

Line 13 ("Your new Path companion has been registered.") is left out: as a game
message from the Trl0l3 static actor the client showed nothing, before or after the
warp, and with the WorldMaster as text owner it crashed the client.

The warp in uses spawn type 0 (fade in): with 15 the hall stayed dark in the client.

Only once Man200 is done; while a quest has Tataru, its own talk runs instead.
]]

TRL0L3_MAN200 = 110013;
TRL0L3_HALL = {181, "PrivateAreaMasterPast", 0, -143.5, 1.0, -163.6, 1.57};	-- facing Tataru
TRL0L3_QUICKSAND = {175, -72.5, 195.0, 72.5, 0.0};	-- in front of the Quicksand Tataru

function trl0l3Ready(player)
	return player:IsQuestCompleted(TRL0L3_MAN200)
		and GetStaticActor("Trl0l3") ~= nil and GetStaticActor("Man200") ~= nil;
end

-- Tataru in the Quicksand: into the Waking Sands.
function trl0l3Invite(player, npc)
	if (not trl0l3Ready(player)) then
		player:EndEvent();
		return;
	end
	player:EndEvent();
	local h = TRL0L3_HALL;
	GetWorldManager():DoZoneChange(player, h[1], h[2], h[3], 0, h[4], h[5], h[6], h[7]);
end

-- Tataru in the Waking Sands: the pick, the name, then back to the Quicksand.
function trl0l3Reselect(player, npc)
	if (not trl0l3Ready(player)) then
		player:EndEvent();
		return;
	end
	local trl = GetStaticActor("Trl0l3");
	callClientFunction(player, "delegateEvent", player, trl, "processSnpcReselectEvent001", player, npc);
	local classId, personality = callClientFunction(player, "delegateEvent", player, GetStaticActor("Man200"), "processSnpcReselect", player, npc);
	if (classId == nil or personality == nil or classId == -1 or personality == -1) then
		trl0l3Back(player);
		return;
	end
	local name = callClientFunction(player, "delegateEvent", player, trl, "processSnpcReName", player, npc);
	if (type(name) ~= "string" or name == "") then
		name = player:GetSNpcNickname();
	end
	player:SetSNpc(name, classId, personality);
	callClientFunction(player, "delegateEvent", player, trl, "processSnpcReselectEvent002", player, npc);
	trl0l3Back(player);
end

-- Out of the Waking Sands, back in front of the Quicksand Tataru.
function trl0l3Back(player)
	player:EndEvent();
	local q = TRL0L3_QUICKSAND;
	GetWorldManager():DoZoneChange(player, q[1], nil, 0, 15, q[2], q[3], q[4], q[5]);
end
