require ("global")
require ("modifiers")
-- allyGlobal.EngageTarget opens J'moldva on the player.
require ("ally")
require ("quests/gla/gla300")

-- Gla300 Unalienable Rights: the Wood Wailers' "friendly" spar in the
-- Wailing Barracks courtyard against the lancer J'moldva (seed 296, bnpc
-- 3949). Beating her leaves the content without hostiles, which fires
-- "battleComplete" to QuestDirectorGla30001. The player can't die in
-- content yet, so losing is being pinned at the 1-HP floor (or the bout
-- running out of time); the content ends that itself and sets the player
-- down in the courtyard.

TICKS_PER_SECOND = 2;
BOUT_LIMIT_TICKS = 6 * 60 * TICKS_PER_SECOND;

-- Per-player bout state (the VM is cached per script path).
boutState = {};

function onCreate(player, contentArea, director)
	local jmoldva = GetWorldManager().SpawnBattleNpcById(3949, contentArea);
	boutState[player.actorId] = { done = false, startTick = nil, jmoldvaId = jmoldva.actorId };
	jmoldva:ChangeState(2);
	player:SetMod(modifiersGlobal.MinimumHpLock, 1);
	director:AddMember(player);
	director:AddMember(director);
	director:AddMember(jmoldva);
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

	local jmoldva = nil;
	local mobs = area:GetMonsters();
	for i = 1, #mobs do
		if mobs[i] and mobs[i].actorId == state.jmoldvaId then
			jmoldva = mobs[i];
		end
	end
	-- She leaves the roster when beaten; battleComplete is on its way.
	if not jmoldva then
		state.done = true;
		return;
	end

	if not state.startTick then
		state.startTick = tick;
	end
	if not jmoldva:IsEngaged() then
		allyGlobal.EngageTarget(jmoldva, owner);
	end

	local timedOut = tick - state.startTick >= BOUT_LIMIT_TICKS;
	if (owner:GetHP() <= 1 or timedOut) then
		state.done = true;
		loseGla300Bout(owner, timedOut);
	end
end

-- Leaving the bout early is a loss; J'moldva will spar again.
function onAbort(player, contentArea, director)
	local state = boutState[player.actorId];
	if state ~= nil then
		state.done = true;
	end
end

function onDestroy()
end
