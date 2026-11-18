require ("global")
require ("modifiers")
-- allyGlobal.EngageTarget opens the foe on the player.
require ("ally")
require ("quests/lnc/lnc306")

-- Lnc306 Necessary Evils: the angry elemental that falls on the caravan,
-- staged in the South Shroud (bnpc 3957). When it falls the
-- content is without hostiles, which fires "battleComplete" to
-- QuestDirectorLnc30601. The player can't die in content yet, so losing is
-- being pinned at the 1-HP floor (or the fight running out of time); the
-- content ends that itself and sets the player down by the road.

TICKS_PER_SECOND = 2;
FIGHT_LIMIT_TICKS = 8 * 60 * TICKS_PER_SECOND;
FOE = 3957;

-- Per-player fight state (the VM is cached per script path).
fightState = {};

function onCreate(player, contentArea, director)
	local state = { done = false, startTick = nil, foeId = nil };
	director:AddMember(player);
	director:AddMember(director);
	local foe = GetWorldManager().SpawnBattleNpcById(FOE, contentArea);
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
	-- The roster can lag the spawn by a tick or two: it counts as down
	-- only once it has been seen.
	if foe then
		state.foeSeen = true;
	elseif state.foeSeen then
		state.done = true;
		return;
	else
		return;
	end
	if not foe:IsEngaged() then
		allyGlobal.EngageTarget(foe, owner);
	end

	if not state.startTick then
		state.startTick = tick;
	end
	local timedOut = tick - state.startTick >= FIGHT_LIMIT_TICKS;
	if (owner:GetHP() <= 1 or timedOut) then
		state.done = true;
		loseLnc306Fight(owner, timedOut);
	end
end

-- Leaving the fight early is a loss; the road stays open for another try.
function onAbort(player, contentArea, director)
	local state = fightState[player.actorId];
	if state ~= nil then
		state.done = true;
	end
end

function onDestroy()
end
