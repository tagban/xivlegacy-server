require ("global")
require ("modifiers")
-- allyGlobal.EngageTarget opens the foe on the player.
require ("ally")
require ("quests/gla/gla306")

-- Gla306 Thrill of the Fight: your debut in the tourney of warriors, on
-- the bloodsands against an Ala Mhigan bladedancer (bnpc 3950, level 36).
-- Beating him leaves the content without hostiles, which fires
-- "battleComplete" to QuestDirectorGla30601. The player can't die in
-- content yet, so losing is being pinned at the 1-HP floor (or the bout
-- running out of time); the content ends that itself and sends the player
-- back to the guild hall.

BNPC_ID = 3950;

TICKS_PER_SECOND = 2;
BOUT_LIMIT_TICKS = 6 * 60 * TICKS_PER_SECOND;

-- Per-player bout state (the VM is cached per script path).
boutState = {};

function onCreate(player, contentArea, director)
	local foe = GetWorldManager().SpawnBattleNpcById(BNPC_ID, contentArea);
	boutState[player.actorId] = { done = false, startTick = nil, foeId = foe.actorId };
	foe:ChangeState(2);
	player:SetMod(modifiersGlobal.MinimumHpLock, 1);
	director:AddMember(player);
	director:AddMember(director);
	director:AddMember(foe);
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
	local state = boutState[owner.actorId];
	if not state or state.done then return end

	local foe = nil;
	local mobs = area:GetMonsters();
	for i = 1, #mobs do
		if mobs[i] and mobs[i].actorId == state.foeId then
			foe = mobs[i];
		end
	end
	-- The foe leaves the roster when beaten; battleComplete is on its way.
	if not foe then
		state.done = true;
		return;
	end

	if not state.startTick then
		state.startTick = tick;
	end
	if not foe:IsEngaged() then
		allyGlobal.EngageTarget(foe, owner);
	end

	local timedOut = tick - state.startTick >= BOUT_LIMIT_TICKS;
	if (owner:GetHP() <= 1 or timedOut) then
		state.done = true;
		loseGla306Bout(owner, timedOut);
	end
end

-- Leaving the bout early is a loss; it can be fought again.
function onAbort(player, contentArea, director)
	local state = boutState[player.actorId];
	if state ~= nil then
		state.done = true;
	end
end

function onDestroy()
end
