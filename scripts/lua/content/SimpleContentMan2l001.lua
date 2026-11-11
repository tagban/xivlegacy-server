require ("global")
require ("modifiers")
require ("ally")
require ("quests/man/man2l0")

--[[

Never the Twain Shall Meet, the duty on Hob's deck (director
QuestDirectorMan2l001). Back on deck after the hold, you find Emerick and
Merodaulyn at each other's throats; the journal tells you to pick a side
and join in (Gamer Escape walkthrough and journal, 1.x):

  * neither of them attacks you until you attack one;
  * the one you attack turns on you, the other stands back;
  * the duty ends when the one you fight falls;
  * you can also stay out of it and let them settle it themselves.

Here the two square off with weapons drawn. The first one the player
strikes is "their" fight; the other goes passive. Staying out for
STAND_ASIDE_SECONDS ends the quarrel on its own. Either way the content
signals "duelOver" and the director plays the deck scenes. The player
pinned at 1 HP is a loss: back on deck, the trigger stays live for a retry.

]]

TICKS_PER_SECOND		= 2;
STAND_ASIDE_SECONDS		= 90;
FIGHT_LIMIT_SECONDS		= 10 * 60;

duelState = {};

function onCreate(player, contentArea, director)
	local state = { done = false, startTick = nil, chosen = nil, ids = {} };
	director:AddMember(player);
	director:AddMember(director);
	for _, id in ipairs(MAN2L0_DUELISTS) do
		local npc = GetWorldManager().SpawnBattleNpcById(id, contentArea);
		-- Weapons drawn, facing each other; nobody is on the player yet.
		npc:ChangeState(2);
		director:AddMember(npc);
		table.insert(state.ids, npc.actorId);
	end
	duelState[player.actorId] = state;
	player:SetMod(modifiersGlobal.MinimumHpLock, 1);
end

function onZoneIn(player, contentArea, director)
	player:ChangeMusic(37); -- the 1.x duty theme
end

local function finish(owner, state, signal)
	state.done = true;
	for _, mob in ipairs(state.live or {}) do
		mob:ChangeState(0);
	end
	owner:ChangeState(0);
	sendSignal(signal);
end

function onUpdate(tick, area)
	if not area then return end
	local owner = nil;
	for player in area:GetPlayers() do
		if player then owner = owner or player end
	end
	if not owner then return end
	local state = duelState[owner.actorId];
	if not state or state.done then return end

	local live = {};
	for _, mob in ipairs(area:GetMonsters()) do
		for _, id in ipairs(state.ids) do
			if mob and mob.actorId == id then
				live[id] = mob;
			end
		end
	end
	state.live = {};
	for _, mob in pairs(live) do table.insert(state.live, mob) end
	-- The roster lags the spawns by a tick or two.
	if not state.startTick then
		if #state.live < #state.ids then return end
		state.startTick = tick;
	end
	local elapsed = tick - state.startTick;

	-- The side the player picked: the first duelist they engaged.
	if state.chosen == nil then
		for _, id in ipairs(state.ids) do
			local mob = live[id];
			if mob and mob:IsEngaged() then
				state.chosen = id;
				owner:SendMessage(0x20, "", "You join the fray!");
				-- The other one stands back.
				for _, other in ipairs(state.ids) do
					if other ~= id and live[other] then
						live[other]:ChangeState(0);
					end
				end
				break;
			end
		end
	end

	if state.chosen == nil then
		-- Left to themselves, the two settle it without you.
		if elapsed >= STAND_ASIDE_SECONDS * TICKS_PER_SECOND then
			owner:SendMessage(0x20, "", "The two settle their quarrel without you.");
			finish(owner, state, "duelOver");
		end
		return;
	end

	local foe = live[state.chosen];
	if foe == nil then
		-- The one you fought is down.
		finish(owner, state, "duelOver");
		return;
	end
	if not foe:IsEngaged() then
		allyGlobal.EngageTarget(foe, owner);
	end
	if owner:GetHP() <= 1 or elapsed >= FIGHT_LIMIT_SECONDS * TICKS_PER_SECOND then
		state.done = true;
		for _, mob in ipairs(state.live) do mob:ChangeState(0) end
		owner:ChangeState(0);
		owner:SetHP(owner:GetMaxHP());
		owner:SetMod(modifiersGlobal.MinimumHpLock, 0);
		owner:SendMessage(0x20, "", "You are defeated.");
		area:ContentFinished();
		warpToDeck(owner);
	end
end

function onAbort(player, contentArea, director)
	local state = duelState[player.actorId];
	if state ~= nil then
		state.done = true;
	end
end

function onDestroy()
end
