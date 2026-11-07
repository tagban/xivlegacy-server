require ("global")
require ("modifiers")
-- allyGlobal.EngageTarget opens the foe on the player.
require ("ally")
require ("quests/thm/thm306")

-- Thm306 Law and the Order: the overweening thaumaturge at the wreck in
-- Western Thanalan (bnpc 3956, a thaumaturge pool). When she falls the
-- content is without hostiles, which fires "battleComplete" to
-- QuestDirectorThm30601. The player can't die in content yet, so losing is
-- being pinned at the 1-HP floor (or the fight running out of time); the
-- content ends that itself and sets the player down at the wreck.

TICKS_PER_SECOND = 2;
FIGHT_LIMIT_TICKS = 8 * 60 * TICKS_PER_SECOND;
RIVAL = 3956;

-- Per-player fight state (the VM is cached per script path).
fightState = {};

function onCreate(player, contentArea, director)
	local state = { done = false, startTick = nil, rivalId = nil };
	director:AddMember(player);
	director:AddMember(director);
	local rival = GetWorldManager().SpawnBattleNpcById(RIVAL, contentArea);
	rival:ChangeState(2);
	director:AddMember(rival);
	state.rivalId = rival.actorId;
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

	local rival = nil;
	local mobs = area:GetMonsters();
	for i = 1, #mobs do
		if mobs[i] and mobs[i].actorId == state.rivalId then
			rival = mobs[i];
		end
	end
	-- The roster can lag the spawn by a tick or two: she counts as down
	-- only once she has been seen.
	if rival then
		state.rivalSeen = true;
	elseif state.rivalSeen then
		state.done = true;
		return;
	else
		return;
	end
	if not rival:IsEngaged() then
		allyGlobal.EngageTarget(rival, owner);
	end

	if not state.startTick then
		state.startTick = tick;
	end
	local timedOut = tick - state.startTick >= FIGHT_LIMIT_TICKS;
	if (owner:GetHP() <= 1 or timedOut) then
		state.done = true;
		loseThm306Fight(owner, timedOut);
	end
end

-- Leaving the fight early is a loss; the wreck stays open for another try.
function onAbort(player, contentArea, director)
	local state = fightState[player.actorId];
	if state ~= nil then
		state.done = true;
	end
end

function onDestroy()
end
