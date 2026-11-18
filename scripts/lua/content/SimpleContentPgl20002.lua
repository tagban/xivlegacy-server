require ("global")
require ("modifiers")
-- allyGlobal.EngageTarget opens the veteran on the player.
require ("ally")
require ("quests/pgl/pgl200")

-- Pgl200 The House Always Wins: the bloodsands match Lady Lewena demands
-- before she pays her loan. A veteran of the Coliseum (seed 194, bnpc 3923)
-- fights you one on one while she cheers from the stands. Beating him
-- leaves the content without hostiles, which fires "battleComplete" to
-- QuestDirectorPgl20002. The player can't die in content yet, so losing is
-- being pinned at the 1-HP floor (or the round running out); the content
-- ends that itself and sends the player back to Singleton.

TICKS_PER_SECOND = 2;
ROUND_LIMIT_TICKS = 5 * 60 * TICKS_PER_SECOND;
CHEER_EVERY_TICKS = 8 * TICKS_PER_SECOND;

-- Per-player match state (the VM is cached per script path).
matchState = {};

function onCreate(player, contentArea, director)
	local veteran = GetWorldManager().SpawnBattleNpcById(3923, contentArea);
	matchState[player.actorId] = { done = false, startTick = nil, veteranId = veteran.actorId, cheer = 0 };
	veteran:ChangeState(2);
	player:SetMod(modifiersGlobal.MinimumHpLock, 1);
	director:AddMember(player);
	director:AddMember(director);
	director:AddMember(veteran);
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
	local state = matchState[owner.actorId];
	if not state or state.done then return end

	local veteran = nil;
	local mobs = area:GetMonsters();
	for i = 1, #mobs do
		if mobs[i] and mobs[i].actorId == state.veteranId then
			veteran = mobs[i];
		end
	end
	-- A dead veteran leaves the roster; battleComplete is on its way.
	if not veteran then
		state.done = true;
		return;
	end

	if not state.startTick then
		state.startTick = tick;
	end
	if not veteran:IsEngaged() then
		allyGlobal.EngageTarget(veteran, owner);
	end

	local elapsed = tick - state.startTick;
	if (elapsed > 0 and elapsed % CHEER_EVERY_TICKS == 0) then
		state.cheer = state.cheer % #LEWENA_CHEERS + 1;
		owner:SendMessage(MESSAGE_TYPE_SAY, "Lady Lewena", LEWENA_CHEERS[state.cheer]);
	end

	if (owner:GetHP() <= 1 or elapsed >= ROUND_LIMIT_TICKS) then
		state.done = true;
		losePgl200Coliseum(owner);
	end
end

-- Leaving the duty early is a loss; the quest stays at Singleton.
function onAbort(player, contentArea, director)
	local state = matchState[player.actorId];
	if state ~= nil then
		state.done = true;
	end
end

function onDestroy()
end
