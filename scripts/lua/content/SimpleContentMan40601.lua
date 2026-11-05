require ("global")
require ("modifiers")
require ("ally")
require ("quests/man/man406")

-- Futures Perfect, Mor Dhona: the imperial patrol you followed east from
-- Camp Revenant's Toll (a hoplomachus, a signifer, a laquearius and their
-- centurion). Beating them ends the fight: the content roster running out
-- of live battle NPCs fires "battleComplete" to the director
-- (QuestDirectorMan40601), which plays the airship scenes and moves you
-- into the children's cave further east, in this same duty. The children
-- and the cave's way out are spawned here from the start; they are event
-- NPCs, so they don't hold battleComplete back.
--
-- Not done from retail: the machina whose cannon could be turned on the
-- patrol, and the centurion fleeing when he is left alone.

FOES = { 3594, 3595, 3596, 3597 };
ENGAGE_RADIUS = 20.0;

-- The cave (a passage under the hills, floor about y 54-55, climbing west
-- and north to its mouth); the children, and the way out at the mouth.
CAVE_CHILDREN = {
	{ class = 1000957, name = "man406_shuddering_child",	x = 306.0, y = 54.5, z = -796.0, rot = -1.57 },
	{ class = 1000958, name = "man406_cowering_child",		x = 312.0, y = 54.4, z = -796.0, rot = -1.57 },
	{ class = 1000959, name = "man406_shivering_child",		x = 306.0, y = 53.7, z = -784.0, rot = -2.36 },
	{ class = 1000960, name = "man406_cried_out_child",		x = 312.0, y = 53.9, z = -790.0, rot = -1.57 },
	{ class = 1000961, name = "man406_terrified_child",		x = 300.0, y = 53.7, z = -788.0, rot = 3.14 },
};
CAVE_EXIT = { x = 225.0, y = 69.2, z = -762.0 };

-- per player: whether the fight has begun
states = {};

function onCreate(player, contentArea, director)
	director:AddMember(player);
	director:AddMember(director);
	for _, id in ipairs(FOES) do
		local mob = GetWorldManager().SpawnBattleNpcById(id, contentArea);
		mob:ChangeState(2);
		director:AddMember(mob);
	end
	for _, child in ipairs(CAVE_CHILDREN) do
		director:AddMember(contentArea:SpawnActor(child.class, child.name, child.x, child.y, child.z, child.rot));
	end
	director:AddMember(contentArea:SpawnActor(CAVE_EXIT_TRIGGER, "man406_cave_exit", CAVE_EXIT.x, CAVE_EXIT.y, CAVE_EXIT.z, 0.0));
	states[player.actorId] = { engaged = false };
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
				state.engaged = true;
			end
		end
	end
end

function onAbort(player, contentArea, director)
end

function onDestroy()
end
