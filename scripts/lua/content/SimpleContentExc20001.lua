require ("global")
require ("modifiers")
-- allyGlobal.EngageTarget opens each lemming on the player.
require ("ally")
require ("quests/exc/exc200")

-- Exc200 Bloody Baptism: culling the tower lemmings at Swiftperch Tower
-- (seed 196, bnpcs 3925-3928). Killing the last one leaves the content
-- without hostiles, which fires "battleComplete" to QuestDirectorExc20001.
-- The player can't die in content yet, so losing is being pinned at the
-- 1-HP floor (or the hunt running out of time); the content ends that
-- itself and sets the player down outside the tower.

TICKS_PER_SECOND = 2;
HUNT_LIMIT_TICKS = 8 * 60 * TICKS_PER_SECOND;
LEMMINGS = { 3925, 3926, 3927, 3928 };

-- Per-player hunt state (the VM is cached per script path).
huntState = {};

function onCreate(player, contentArea, director)
	local state = { done = false, startTick = nil, lemmingIds = {} };
	director:AddMember(player);
	director:AddMember(director);
	for i = 1, #LEMMINGS do
		local lemming = GetWorldManager().SpawnBattleNpcById(LEMMINGS[i], contentArea);
		lemming:ChangeState(2);
		director:AddMember(lemming);
		state.lemmingIds[lemming.actorId] = true;
	end
	huntState[player.actorId] = state;
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
	local state = huntState[owner.actorId];
	if not state or state.done then return end

	local alive = 0;
	local mobs = area:GetMonsters();
	for i = 1, #mobs do
		local mob = mobs[i];
		if mob and state.lemmingIds[mob.actorId] then
			alive = alive + 1;
			if not mob:IsEngaged() then
				allyGlobal.EngageTarget(mob, owner);
			end
		end
	end
	-- The last lemming down leaves the roster; battleComplete is on its way.
	if alive == 0 then
		state.done = true;
		return;
	end

	if not state.startTick then
		state.startTick = tick;
	end
	if (owner:GetHP() <= 1 or tick - state.startTick >= HUNT_LIMIT_TICKS) then
		state.done = true;
		loseExc200Hunt(owner);
	end
end

-- Leaving the hunt early is a loss; the tower stays open for another try.
function onAbort(player, contentArea, director)
	local state = huntState[player.actorId];
	if state ~= nil then
		state.done = true;
	end
end

function onDestroy()
end
