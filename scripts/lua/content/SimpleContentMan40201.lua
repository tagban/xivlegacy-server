require ("global")
require ("modifiers")
require ("ally")
require ("quests/man/man402")

-- Of Men They Sing, the scout's ravine in the East Shroud: two imperial
-- bloodhounds. Beating them ends it: the content roster running out of
-- live battle NPCs fires "battleComplete" to the director
-- (QuestDirectorMan40201), which plays the scene after the fight. Your
-- companion is in the scenes only, since an ally in the roster would hold
-- battleComplete back too.
--
-- Your companion's three warnings (protect the scout, the rings on the
-- hounds' legs, strike the rings) come from the quest's text sheet, one
-- line per personality, spaced out once the fight has begun.

HOUNDS = { 3592, 3593 };
ENGAGE_RADIUS = 20.0;	-- the hounds turn from the scout to you this close

-- say id blocks (nine each), and the tick (500 ms) after the first
-- engagement at which each is said
BARKS = {
	{ base = 222, tick = 0 },	-- protect the scout
	{ base = 231, tick = 12 },	-- something on the hounds' legs
	{ base = 240, tick = 24 },	-- the rings control them: strike them off
};

-- per player: the tick the fight began and the next bark
states = {};

function onCreate(player, contentArea, director)
	director:AddMember(player);
	director:AddMember(director);
	for _, id in ipairs(HOUNDS) do
		local mob = GetWorldManager().SpawnBattleNpcById(id, contentArea);
		mob:ChangeState(2);
		director:AddMember(mob);
	end
	states[player.actorId] = { startTick = nil, nextBark = 1 };
	-- The player can't die in content yet (no death/return flow there).
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
	if not owner or (owner.positionX == 0 and owner.positionZ == 0) then return end
	local state = states[owner.actorId];
	if not state then return end

	for _, mob in ipairs(area:GetMonsters()) do
		if (mob and not mob:IsEngaged()) then
			local dx = mob.positionX - owner.positionX;
			local dz = mob.positionZ - owner.positionZ;
			if (math.sqrt(dx * dx + dz * dz) <= ENGAGE_RADIUS) then
				allyGlobal.EngageTarget(mob, owner);
				state.startTick = state.startTick or tick;
			end
		end
	end

	local bark = BARKS[state.nextBark];
	if (state.startTick and bark and tick - state.startTick >= bark.tick) then
		owner:SendGameMessage(owner:GetQuest(110018), companionLine(owner, bark.base), 0x20);
		state.nextBark = state.nextBark + 1;
	end
end

function onAbort(player, contentArea, director)
end

function onDestroy()
end
