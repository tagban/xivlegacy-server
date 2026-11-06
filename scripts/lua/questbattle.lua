require ("global")
require ("modifiers")
-- allyGlobal.EngageTarget opens a foe on the player.
require ("ally")

--[[

Shared flow for side-quest fights that the client runs as a
SimpleQuestBattle duty (client class /Director/Quest/SimpleQuestBattle/
QuestDirector<Name>, content SimpleContent<Name>).

  quest script:   questBattle.start(player, "Etc2u001", FIGHT)
  director:       questBattle.runDirector(player, actor, QUEST_ID, onWin)
  content:        questBattle.create / update / abort

A fight is won when every foe is down: the content then has no hostiles,
which fires "battleComplete" to the director, and the director calls the
quest's win function (a new sequence, a scene, an item). The player can't
die in content yet, so a loss is being pinned at the 1-HP floor or running
out of time; the content ends that itself. Either way the player is set
down at the fight's spot, which must lie outside the trigger circle so a
retry means walking back in.

The director and the content run in separate Lua states, and each script
path keeps its own VM, so the content's per-player state lives here in
questBattle.state of that content's VM.

]]

questBattle = {};
questBattle.state = {};

TICKS_PER_SECOND = 2;

-- spot = { zoneId, x, y, z, rotation }
function questBattle.warp(player, spot)
	GetWorldManager():DoZoneChange(player, spot[1], nil, 0, 15, spot[2], spot[3], spot[4], spot[5]);
end

-- Quest side: enter the duty at the fight's spot.
function questBattle.start(player, name, spot)
	local contentArea = player.CurrentArea:CreateContentArea(player,
		"/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", name,
		"SimpleContent" .. name, "Quest/SimpleQuestBattle/QuestDirector" .. name, spot[1]);
	if (contentArea == nil) then
		player:EndEvent();
		questBattle.warp(player, spot);
		return;
	end
	local director = contentArea:GetContentDirector();
	player:AddDirector(director);
	director:StartDirector(false);
	player:KickEvent(director, "noticeEvent", true);
	player:SetLoginDirector(director);
	player:EndEvent();
	GetWorldManager():DoZoneChangeContent(player, contentArea, spot[2], spot[3], spot[4], spot[5], 16);
end

-- Leave the duty (after a win or a loss) and set the player down at spot.
function questBattle.leave(player, spot)
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	questBattle.warp(player, spot);
end

-- Director side. The entry kick raises the loading veil even for a duty in
-- the same zone; questBaseRewardSeting lifts it. A duty that ends any other
-- way (a loss, leaving) purges this coroutine with the content.
-- onWin(player, quest) changes the quest, then calls questBattle.leave.
function questBattle.runDirector(player, actor, questId, onWin)
	-- By id: GetQuest resolves names only for the opening quests.
	local quest = player:GetQuest(questId);
	callClientFunction(player, "delegateEvent", player, quest, "questBaseRewardSeting");
	player:EndEvent();

	waitForSignal("battleComplete");
	wait(2);
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	onWin(player, quest);
end

-- Content side: spawn the foes (battle npc spawn ids) on the player.
function questBattle.create(player, contentArea, director, bnpcIds)
	local state = { done = false, startTick = nil, seen = false, foeIds = {} };
	director:AddMember(player);
	director:AddMember(director);
	for i = 1, #bnpcIds do
		local foe = GetWorldManager().SpawnBattleNpcById(bnpcIds[i], contentArea);
		foe:ChangeState(2);
		director:AddMember(foe);
		state.foeIds[foe.actorId] = true;
	end
	questBattle.state[player.actorId] = state;
	player:SetMod(modifiersGlobal.MinimumHpLock, 1);
end

-- Content side, every tick: keep the foes on the player, and call
-- onLose(player, timedOut) once when the player is pinned or time is up.
function questBattle.update(tick, area, limitSeconds, onLose)
	if not area then return end
	local owner = nil;
	for player in area:GetPlayers() do
		if player then owner = owner or player end
	end
	if not owner then return end
	local state = questBattle.state[owner.actorId];
	if not state or state.done then return end

	local foes = {};
	local mobs = area:GetMonsters();
	for i = 1, #mobs do
		if mobs[i] and state.foeIds[mobs[i].actorId] then
			table.insert(foes, mobs[i]);
		end
	end
	-- The roster can lag the spawns by a tick or two: the fight counts as
	-- over only once a foe has been seen.
	if #foes > 0 then
		state.seen = true;
	elseif state.seen then
		-- All down: battleComplete is on its way to the director.
		state.done = true;
		return;
	end
	for i = 1, #foes do
		if not foes[i]:IsEngaged() then
			allyGlobal.EngageTarget(foes[i], owner);
		end
	end

	if not state.startTick then
		state.startTick = tick;
	end
	local timedOut = tick - state.startTick >= limitSeconds * TICKS_PER_SECOND;
	if (owner:GetHP() <= 1 or timedOut) then
		state.done = true;
		if (timedOut) then
			owner:SendMessage(0x20, "", "Time has run out.");
		else
			owner:SendMessage(0x20, "", "You are defeated.");
		end
		onLose(owner, timedOut);
	end
end

-- Content side: leaving early is a loss; the circle stays open for a retry.
function questBattle.abort(player)
	local state = questBattle.state[player.actorId];
	if state ~= nil then
		state.done = true;
	end
end
