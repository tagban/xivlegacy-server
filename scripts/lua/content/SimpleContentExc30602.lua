require ("global")
require ("modifiers")
-- allyGlobal.EngageTarget opens the foes on the player.
require ("ally")
require ("quests/exc/exc306")

-- Exc306 Captain's Orders: Moenskaet and his right and left hands, staged
-- in the Astalicia's lounge (bnpc 3959-3961). When all three are down the
-- content is without hostiles, which fires "battleComplete" to
-- QuestDirectorExc30602. The player can't die in content yet, so losing is
-- being pinned at the 1-HP floor (or the fight running out of time); the
-- content ends that itself and sets the player back on deck.

TICKS_PER_SECOND = 2;
FIGHT_LIMIT_TICKS = 8 * 60 * TICKS_PER_SECOND;
FOES = { 3959, 3960, 3961 };

-- Per-player fight state (the VM is cached per script path).
fightState = {};

function onCreate(player, contentArea, director)
	local state = { done = false, startTick = nil, foeIds = {}, seen = false };
	director:AddMember(player);
	director:AddMember(director);
	for _, id in ipairs(FOES) do
		local foe = GetWorldManager().SpawnBattleNpcById(id, contentArea);
		foe:ChangeState(2);
		director:AddMember(foe);
		state.foeIds[foe.actorId] = true;
	end
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

	local alive = 0;
	local mobs = area:GetMonsters();
	for i = 1, #mobs do
		local foe = mobs[i];
		if foe and state.foeIds[foe.actorId] then
			alive = alive + 1;
			if not foe:IsEngaged() then
				allyGlobal.EngageTarget(foe, owner);
			end
		end
	end
	-- The roster can lag the spawn by a tick or two: they count as down
	-- only once they have been seen.
	if alive > 0 then
		state.seen = true;
	elseif state.seen then
		state.done = true;
		return;
	else
		return;
	end

	if not state.startTick then
		state.startTick = tick;
	end
	local timedOut = tick - state.startTick >= FIGHT_LIMIT_TICKS;
	if (owner:GetHP() <= 1 or timedOut) then
		state.done = true;
		loseExc306Fight(owner, timedOut);
	end
end

-- Leaving the fight early is a loss; the doors stay open for another try.
function onAbort(player, contentArea, director)
	local state = fightState[player.actorId];
	if state ~= nil then
		state.done = true;
	end
end

function onDestroy()
end
