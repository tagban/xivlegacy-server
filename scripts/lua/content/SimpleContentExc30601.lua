require ("global")
require ("modifiers")
-- allyGlobal.EngageTarget opens the foe on the player.
require ("ally")
require ("quests/exc/exc306")

-- Exc306 Captain's Orders: Moenskaet the Honorbound's beating, staged in
-- the Astalicia's lounge (bnpc 3958). Neither side can fall: both are held
-- at 1 HP. The beating ends when the player is pinned at 1 HP or after five
-- minutes, and either way the quest goes on (endExc306Beating).

TICKS_PER_SECOND = 2;
BEATING_LIMIT_TICKS = 5 * 60 * TICKS_PER_SECOND;
FOE = 3958;

-- Per-player fight state (the VM is cached per script path).
fightState = {};

function onCreate(player, contentArea, director)
	local state = { done = false, startTick = nil, foeId = nil };
	director:AddMember(player);
	director:AddMember(director);
	local foe = GetWorldManager().SpawnBattleNpcById(FOE, contentArea);
	foe:SetMod(modifiersGlobal.MinimumHpLock, 1);
	foe:ChangeState(2);
	director:AddMember(foe);
	state.foeId = foe.actorId;
	fightState[player.actorId] = state;
	player:SetMod(modifiersGlobal.MinimumHpLock, 1);
end

function onZoneIn(player, contentArea, director)
	player:ChangeMusic(37); -- the 1.x duty theme
end

function onUpdate(tick, area)
	if not area then return end
	local owner = nil;
	for player in area:GetPlayers() do
		if player then owner = owner or player end
	end
	if not owner then return end
	local state = fightState[owner.actorId];
	if not state or state.done then return end

	local foe = nil;
	local mobs = area:GetMonsters();
	for i = 1, #mobs do
		if mobs[i] and mobs[i].actorId == state.foeId then
			foe = mobs[i];
		end
	end
	if not foe then return end
	if not foe:IsEngaged() then
		allyGlobal.EngageTarget(foe, owner);
	end

	if not state.startTick then
		state.startTick = tick;
	end
	if (owner:GetHP() <= 1 or tick - state.startTick >= BEATING_LIMIT_TICKS) then
		state.done = true;
		endExc306Beating(owner);
	end
end

-- Leaving early: the door by Waekbyrt begins it again.
function onAbort(player, contentArea, director)
	local state = fightState[player.actorId];
	if state ~= nil then
		state.done = true;
	end
end

function onDestroy()
end
