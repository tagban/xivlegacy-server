--[[

Escort duties

The shared loop behind quest escorts: a duty instance in which one or more
escortees follow the player along a route, enemies on the way are pulled
onto the player, and the duty fails when an escortee falls or time runs out.
It is the man0l1 / man0g1 opening escorts' machinery (SimpleContentMan0l101,
SimpleContentMan0g101) made reusable; those two keep their own copies.

A duty is a table handed to the content script's hooks:

	duty = {
		quest = 110014,                   -- quest id (GetQuest knows few names)
		escortees = {                     -- spawned in onCreate, first one leads
			{ bnpcId = 52, look = function(player) return classId end,
			  name = function(player) return "Nickname" end },
		},
		mobs = { 53, 54, 55 },            -- enemies, spawned in onCreate
		legs = {                          -- walked in order
			{ goal = { x =, z = }, radius = 8, signal = "legOne",
			  resumeSequence = 25 },        -- next leg once the quest is here
			{ goal = { x =, z = }, radius = 10, signal = "legTwo" },
		},
		minutes = 30,                     -- time limit
		contentId = nil,                  -- the countdown's title (client content list), optional
		failSequence = 15,                -- quest step a failure rolls back to
		eject = { x =, y =, z =, rot = }, -- where a failure leaves the player
		barks = { start =, ambush =, clear =, hurt = },  -- optional say ids or strings
	}

	function onCreate(player, area, director) escortGlobal.Create(duty, player, area, director) end
	function onUpdate(tick, area)              escortGlobal.Update(duty, tick, area) end
	function onAbort(player, area, director)   escortGlobal.Abort(duty, player, area) end

A leg's arrival sends its signal to the duty's director, which plays the
scenes and advances the quest; the escort holds until the quest reaches the
leg's resumeSequence, then walks the next leg. The last leg's director ends
the content.

]]

require ("global")
require ("modifiers")
require ("ally")
require ("contenttimer")

escortGlobal = {};

-- worldMaster duty texts (the client's duty block, as the openings use them).
local TEXT_PROTECT_ESCORTEE	= 51005;	-- "Protect <displayName> from harm."
local TEXT_TIME_REMAINING	= 25018;	-- "There are <N> minutes remaining."

-- Pacing and geometry, from the opening escorts (500 ms ticks).
local TICKS_PER_SECOND	= 2;
local RUN_STEP			= 3.4;	-- yalms per tick at run pace
local FOLLOW_GAP		= 5.0;	-- the lead closes to this far from the player
local TRAIL_GAP			= 4.0;	-- later escortees trail the one before
local ENGAGE_RADIUS		= 18.0;	-- an enemy this close to the party engages the player
local HOLD_RADIUS		= 28.0;	-- an enemy this close holds the walk
local HURT_COOLDOWN		= 10;	-- ticks between "hurt" barks
-- The duty banners wait this long after the escort is first seen in place,
-- so they don't land while the client is still loading.
local BANNER_DELAY		= 8;

-- Per-player state: the content VM is shared per script path, so a scalar
-- would mix concurrent runs.
escortGlobal.states = {};

local function dist2d(ax, az, bx, bz)
	local dx = ax - bx;
	local dz = az - bz;
	return math.sqrt(dx * dx + dz * dz);
end

-- A spawn's roster position is (0,0,0) until it syncs; skip it until then.
local function positionLive(a)
	return a and not (a.positionX == 0 and a.positionY == 0 and a.positionZ == 0);
end

local function bark(owner, duty, which)
	local b = duty.barks and duty.barks[which];
	if (b == nil) then
		return;
	end
	if (type(b) == "number") then
		owner:SendGameMessage(owner:GetQuest(duty.quest), b, 0x20);
	else
		owner:SendMessage(0x20, "", b);
	end
end

-- Steps `who` toward (x, z) at run pace, stopping `gap` short.
local function stepToward(who, x, y, z, gap)
	local d = dist2d(who.positionX, who.positionZ, x, z);
	if (d <= gap) then
		return;
	end
	local dx = (x - who.positionX) / d;
	local dz = (z - who.positionZ) / d;
	local step = math.min(RUN_STEP, d - gap * 0.5);
	who:MoveTo(who.positionX + dx * step, y, who.positionZ + dz * step, math.atan(dx, dz), 2);
end

function escortGlobal.Create(duty, player, area, director)
	local state = {
		done = false,
		leg = 1,
		waiting = false,      -- a leg arrived; holding for the director
		startTick = nil,
		reminded = {},
		started = false,
		seenTick = nil,
		escorteeIds = {},
		hp = {},
		lastHurtTick = nil,
		lastNear = 0,
	};
	escortGlobal.states[player.actorId] = state;

	local members = {};
	for i, e in ipairs(duty.escortees) do
		local look = e.look and e.look(player) or nil;
		local name = e.name and e.name(player) or nil;
		local actor = GetWorldManager().SpawnBattleNpcById(e.bnpcId, area, look, name);
		state.escorteeIds[i] = actor.actorId;
		-- Civilian idle: an escortee isn't fighting.
		actor:ChangeState(0);
		table.insert(members, actor);
	end
	for _, id in ipairs(duty.mobs or {}) do
		local mob = GetWorldManager().SpawnBattleNpcById(id, area);
		mob:ChangeState(2);
		table.insert(members, mob);
	end

	-- The player can't die in content yet (no death/return flow there), so
	-- the escortees falling is the only way to lose, as in the openings.
	player:SetMod(modifiersGlobal.MinimumHpLock, 1);

	director:AddMember(player);
	director:AddMember(director);
	for _, m in ipairs(members) do
		director:AddMember(m);
	end
end

-- Rolls the quest back, ends the content and puts the player outside.
local function fail(duty, owner, area, state)
	state.done = true;
	owner:GetQuest(duty.quest):StartSequence(duty.failSequence);
	owner:SetMod(modifiersGlobal.MinimumHpLock, 0);
	area:ContentFinished();
	-- ContentFinished also purges the director's coroutine parked on a
	-- leg signal, so a retry can't fire a stale arrival.
	GetWorldManager():WarpToPublicArea(owner, duty.eject.x, duty.eject.y, duty.eject.z, duty.eject.rot);
end

function escortGlobal.Abort(duty, player, area)
	local state = escortGlobal.states[player.actorId];
	if (state == nil or state.done) then
		return;
	end
	fail(duty, player, area, state);
end

function escortGlobal.Update(duty, tick, area)
	if not area then return end
	local owner = nil;
	for player in area:GetPlayers() do
		if player then owner = owner or player end
	end
	if not owner then return end
	local state = escortGlobal.states[owner.actorId];
	if not state or state.done then return end

	-- Timer and its reminders.
	state.startTick = state.startTick or tick;
	local limit = (duty.minutes or 30) * 60 * TICKS_PER_SECOND;
	local elapsed = tick - state.startTick;
	if (elapsed >= limit) then
		fail(duty, owner, area, state);
		return;
	end
	for _, left in ipairs({20, 10, 5}) do
		if (left < (duty.minutes or 30) and not state.reminded[left]
				and elapsed >= limit - left * 60 * TICKS_PER_SECOND) then
			state.reminded[left] = true;
			owner:SendGameMessage(GetWorldMaster(), TEXT_TIME_REMAINING, 0x20, left);
		end
	end

	-- Escortees: the rosters are live-only, so a fallen one just vanishes.
	local escortees = {};
	for _, ally in ipairs(area:GetAllies()) do
		for i, id in ipairs(state.escorteeIds) do
			if (ally and ally.actorId == id) then
				escortees[i] = ally;
			end
		end
	end
	local alive = 0;
	for i = 1, #state.escorteeIds do
		if escortees[i] then alive = alive + 1 end
	end
	if (alive < #state.escorteeIds) then
		if state.seenTick then
			fail(duty, owner, area, state);
		end
		-- Before the first sighting the roster isn't filled yet.
		return;
	end
	local lead = escortees[1];
	if not positionLive(lead) or not positionLive(owner) then
		return;
	end
	if not state.started then
		state.seenTick = state.seenTick or tick;
		if (tick - state.seenTick < BANNER_DELAY) then
			return;
		end
		state.started = true;
		-- "Protect <name>" reads the lead's catalog name; for a custom-named
		-- escortee (a Path companion) the client script errors on it.
		if (duty.escortees[1].name == nil) then
			owner:SendGameMessage(GetWorldMaster(), TEXT_PROTECT_ESCORTEE, 0x20, lead.actorId);
		end
		-- "You are now bound by duty." is the client's own, on joining the
		-- content group.
		owner:SendGameMessage(GetWorldMaster(), TEXT_TIME_REMAINING, 0x20, duty.minutes or 30);
		ShowContentTimer(owner, (limit - elapsed) / TICKS_PER_SECOND, duty.contentId);
		bark(owner, duty, "start");
	end

	-- "Hurt" barks when an escortee loses HP.
	local hurt = false;
	for i, e in ipairs(escortees) do
		local hp = e:GetHP();
		if (state.hp[i] ~= nil and hp < state.hp[i]) then hurt = true end
		state.hp[i] = hp;
	end
	if (hurt and (state.lastHurtTick == nil or tick - state.lastHurtTick >= HURT_COOLDOWN)) then
		state.lastHurtTick = tick;
		bark(owner, duty, "hurt");
	end

	-- Enemies near the party engage the player; any nearby holds the walk.
	local near, engaged = 0, false;
	for _, mob in ipairs(area:GetMonsters()) do
		if (mob and positionLive(mob)) then
			local d = math.min(
				dist2d(mob.positionX, mob.positionZ, lead.positionX, lead.positionZ),
				dist2d(mob.positionX, mob.positionZ, owner.positionX, owner.positionZ));
			if (d <= HOLD_RADIUS) then near = near + 1 end
			if mob:IsEngaged() then
				engaged = true;
			elseif (d <= ENGAGE_RADIUS) then
				allyGlobal.EngageTarget(mob, owner);
				bark(owner, duty, "ambush");
			end
		end
	end
	if (near == 0 and state.lastNear > 0) then
		bark(owner, duty, "clear");
	end
	state.lastNear = near;
	if (near > 0 or engaged) then
		return;
	end

	-- A leg reached: hand it to the director, then wait for the quest to
	-- move on before the next one.
	local leg = duty.legs[state.leg];
	if state.waiting then
		local resume = leg.resumeSequence;
		if (resume ~= nil and owner:GetQuest(duty.quest):getSequence() == resume) then
			state.waiting = false;
			state.leg = state.leg + 1;
		end
		return;
	end
	if (leg == nil) then
		return;
	end
	-- The escortee has to make it too, not just the player.
	local radius = leg.radius or 10;
	if (dist2d(owner.positionX, owner.positionZ, leg.goal.x, leg.goal.z) <= radius
			and dist2d(lead.positionX, lead.positionZ, leg.goal.x, leg.goal.z) <= radius + FOLLOW_GAP + 3) then
		state.waiting = true;
		if (state.leg == #duty.legs) then
			state.done = true;
		end
		sendSignal(leg.signal);
		return;
	end

	-- The escortees follow: the lead keeps up with the player, the rest
	-- trail the one before.
	stepToward(lead, owner.positionX, owner.positionY, owner.positionZ, FOLLOW_GAP);
	for i = 2, #escortees do
		local before = escortees[i - 1];
		stepToward(escortees[i], before.positionX, before.positionY, before.positionZ, TRAIL_GAP);
	end
end
