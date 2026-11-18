require ("global")
require ("modifiers")
require ("ally")
require ("quests/man/man406")

-- Futures Perfect, Mor Dhona: the imperial patrol you followed east from
-- Camp Revenant's Toll (a hoplomachus, a signifer, a laquearius and their
-- centurion). Beating them ends the fight: the content roster running out
-- of live battle NPCs fires "battleComplete" to the director
-- (QuestDirectorMan40601), which plays the airship scenes and moves you
-- on to the children's cave (its own duty, SimpleContentMan40602).
--
-- Not done from retail: the machina whose cannon could be turned on the
-- patrol, and the centurion fleeing when he is left alone.

FOES = { 3594, 3595, 3596, 3597 };
ENGAGE_RADIUS = 20.0;

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
