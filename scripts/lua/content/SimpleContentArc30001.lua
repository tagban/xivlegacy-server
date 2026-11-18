require ("global")
require ("modifiers")
-- allyGlobal.EngageTarget opens each foe on the player.
require ("ally")
require ("quests/arc/arc300")

-- Arc300 The Foreboding Forest: the heretics' ambush in the North Shroud
-- (seed 294, bnpcs 3944-3945: a bandit archer and a thunder mage). Killing
-- the last one leaves the content without hostiles, which fires
-- "battleComplete" to QuestDirectorArc30001.
-- The player can't die in content yet, so losing is being pinned at the
-- 1-HP floor (or the fight running out of time); the content ends that
-- itself and sets the player down where the fight began.

TICKS_PER_SECOND = 2;
FIGHT_LIMIT_TICKS = 8 * 60 * TICKS_PER_SECOND;
FOES = { 3944, 3945 };

-- Per-player fight state (the VM is cached per script path).
fightState = {};

function onCreate(player, contentArea, director)
	local state = { done = false, startTick = nil, foeIds = {} };
	director:AddMember(player);
	director:AddMember(director);
	for i = 1, #FOES do
		local foe = GetWorldManager().SpawnBattleNpcById(FOES[i], contentArea);
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
		local mob = mobs[i];
		if mob and state.foeIds[mob.actorId] then
			alive = alive + 1;
			if not mob:IsEngaged() then
				allyGlobal.EngageTarget(mob, owner);
			end
		end
	end
	-- The last foe down leaves the roster; battleComplete is on its way.
	if alive == 0 then
		state.done = true;
		return;
	end

	if not state.startTick then
		state.startTick = tick;
	end
	local timedOut = tick - state.startTick >= FIGHT_LIMIT_TICKS;
	if (owner:GetHP() <= 1 or timedOut) then
		state.done = true;
		loseArc300Fight(owner, timedOut);
	end
end

-- Leaving the fight early is a loss; the spot stays open for another try.
function onAbort(player, contentArea, director)
	local state = fightState[player.actorId];
	if state ~= nil then
		state.done = true;
	end
end

function onDestroy()
end
