require ("global")
require ("modifiers")
require ("ally")

--[[

Quest duties fought beside NPC allies, with the foes coming in waves.

	fight = {
		allies = { 3470, 3471 },          -- battle npc ids, player side (allegiance 1)
		waves = { { 3480 }, { 3481, 3482 } }, -- foes; the next wave joins when one is down
		limitSeconds = 20 * 60,
		failWhenAlliesFall = false,       -- every ally down = the duty fails (Man2u0)
		foesOnAllies = false,             -- foes open on an ally rather than the player (Man2g0)
		winSignal = "allyFightWon",       -- sent to the director when the last wave is down
	}

	content: onCreate  -> allyFight.create(fight, player, area, director)
	         onUpdate  -> allyFight.update(fight, tick, area, onLose)
	         onAbort   -> allyFight.abort(player)

onLose(owner, area, why) runs once when the player is pinned at 1 HP, time
runs out or (failWhenAlliesFall) every ally is down; why is "defeated",
"time" or "allies". It ends the content and puts the player somewhere.

Everyone is spawned in onCreate: a spawn queued from a content's onUpdate
is never applied (client run 2026-11-11, Etc3u1's second pair). The later
waves stand idle where their spawn rows put them, out of the way, until
their turn. Allies can't die either (a 1 HP floor). With failWhenAlliesFall
an ally at the floor has fallen and sits out; without it the allies fight
on (retail Man2g0 replaced a fallen ally after a while, but a battle npc
handle has no SetHP to bring one back, and a spawn can't come later).

The content VM is shared per script path, so state is kept per player.

]]

allyFight = {};
allyFight.states = {};

local TICKS_PER_SECOND = 2;

local function spawn(area, id, director)
	local npc = GetWorldManager().SpawnBattleNpcById(id, area);
	if director ~= nil then
		director:AddMember(npc);
	end
	return npc;
end

function allyFight.create(fight, player, area, director)
	local state = {
		done = false, startTick = nil, wave = 1, seenWave = false,
		allyIds = {}, foeWave = {}, fallen = {}, seenAllies = false,
	};
	allyFight.states[player.actorId] = state;
	director:AddMember(player);
	director:AddMember(director);
	for _, id in ipairs(fight.allies) do
		local npc = spawn(area, id, director);
		npc:ChangeState(2);
		npc:SetMod(modifiersGlobal.MinimumHpLock, 1);
		state.allyIds[npc.actorId] = id;
	end
	for w, ids in ipairs(fight.waves) do
		for _, id in ipairs(ids) do
			local npc = spawn(area, id, director);
			-- The first wave stands ready; the others wait their turn.
			npc:ChangeState(w == 1 and 2 or 0);
			state.foeWave[npc.actorId] = w;
		end
	end
	player:SetMod(modifiersGlobal.MinimumHpLock, 1);
end

function allyFight.abort(player)
	local state = allyFight.states[player.actorId];
	if state ~= nil then
		state.done = true;
	end
end

local function lose(state, owner, area, onLose, why)
	state.done = true;
	owner:ChangeState(0);
	owner:SetHP(owner:GetMaxHP());
	owner:SetMod(modifiersGlobal.MinimumHpLock, 0);
	onLose(owner, area, why);
end

function allyFight.update(fight, tick, area, onLose)
	if not area then return end
	local owner = nil;
	for player in area:GetPlayers() do
		if player then owner = owner or player end
	end
	if not owner then return end
	local state = allyFight.states[owner.actorId];
	if not state or state.done then return end
	state.startTick = state.startTick or tick;
	local elapsed = tick - state.startTick;

	-- Allies still standing, and the ones at the floor.
	local allies, standing = {}, 0;
	for _, a in ipairs(area:GetAllies()) do
		if a and state.allyIds[a.actorId] then
			table.insert(allies, a);
			state.seenAllies = true;
			if fight.failWhenAlliesFall and state.fallen[a.actorId] == nil and a:GetHP() <= 1 then
				-- Fallen: out of the fight.
				state.fallen[a.actorId] = tick;
				a:ChangeState(0);
			end
			if state.fallen[a.actorId] == nil then
				standing = standing + 1;
			end
		end
	end
	if fight.failWhenAlliesFall and state.seenAllies and standing == 0 then
		owner:SendMessage(0x20, "", "Your allies have fallen.");
		lose(state, owner, area, onLose, "allies");
		return;
	end

	-- This wave's foes still up (the roster only holds the living).
	local foes = {};
	for _, m in ipairs(area:GetMonsters()) do
		if m and state.foeWave[m.actorId] == state.wave then
			table.insert(foes, m);
		end
	end
	-- The roster lags the spawns by a tick or two.
	if #foes > 0 then state.seenWave = true end

	-- A wave down: the next one joins, or the fight is won.
	if state.seenWave and #foes == 0 then
		if state.wave >= #fight.waves then
			state.done = true;
			owner:ChangeState(0);
			owner:SetMod(modifiersGlobal.MinimumHpLock, 0);
			sendSignal(fight.winSignal);
			return;
		end
		state.wave = state.wave + 1;
		state.seenWave = false;
		return;
	end

	-- Everyone into the fight: foes on the player (or an ally), allies on a foe.
	local up = {};
	for _, a in ipairs(allies) do
		if state.fallen[a.actorId] == nil then table.insert(up, a) end
	end
	for i, foe in ipairs(foes) do
		if not foe:IsEngaged() then
			foe:ChangeState(2);
			if fight.foesOnAllies and #up > 0 then
				allyGlobal.EngageTarget(foe, up[((i - 1) % #up) + 1]);
			else
				allyGlobal.EngageTarget(foe, owner);
			end
		end
	end
	for i, a in ipairs(up) do
		if not a:IsEngaged() and #foes > 0 then
			allyGlobal.EngageTarget(a, foes[((i - 1) % #foes) + 1]);
		end
	end

	if owner:GetHP() <= 1 then
		owner:SendMessage(0x20, "", "You are defeated.");
		lose(state, owner, area, onLose, "defeated");
	elseif elapsed >= (fight.limitSeconds or 1200) * TICKS_PER_SECOND then
		owner:SendMessage(0x20, "", "Time has run out.");
		lose(state, owner, area, onLose, "time");
	end
end
