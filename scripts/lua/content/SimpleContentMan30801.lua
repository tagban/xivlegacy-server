require ("global")
require ("modifiers")
require ("ally")

-- Lord Errant, Ifrit's summoning in Paglth'an: three captives his flames
-- have tempered, and the Amalj'aa who brought them. Beating them all ends
-- it; the content roster running out of live hostiles fires
-- "battleComplete" to the director (QuestDirectorMan30801), which plays
-- Ifrit's questions. Seed 170 holds them.

MOBS = { 3584, 3585, 3586, 3587, 3588, 3589, 3590, 3591 };
ENGAGE_RADIUS = 15.0;	-- anyone this close to the player joins: the captives first

function onCreate(player, contentArea, director)
	director:AddMember(player);
	director:AddMember(director);
	for _, id in ipairs(MOBS) do
		local mob = GetWorldManager().SpawnBattleNpcById(id, contentArea);
		mob:ChangeState(2);
		director:AddMember(mob);
	end
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
	for _, mob in ipairs(area:GetMonsters()) do
		if (mob and not mob:IsEngaged()) then
			local dx = mob.positionX - owner.positionX;
			local dz = mob.positionZ - owner.positionZ;
			if (math.sqrt(dx * dx + dz * dz) <= ENGAGE_RADIUS) then
				allyGlobal.EngageTarget(mob, owner);
			end
		end
	end
end

function onAbort(player, contentArea, director)
end

function onDestroy()
end
