require ("global")
require ("modifiers")
-- allyGlobal.EngageTarget opens the challenger on the player.
require ("ally")
require ("quests/gla/gla200")

-- Gla200 All Bark and No Bite: a preliminary bout on the bloodsands
-- against an Ala Mhigan challenger (seed 195, bnpc 3924). Beating him
-- leaves the content without hostiles, which fires "battleComplete" to
-- QuestDirectorGla20001. The player can't die in content yet, so losing is
-- being pinned at the 1-HP floor (or the round running out); the content
-- ends that itself and sends the player back to the guild hall.

TICKS_PER_SECOND = 2;
ROUND_LIMIT_TICKS = 5 * 60 * TICKS_PER_SECOND;

-- Per-player bout state (the VM is cached per script path).
boutState = {};

function onCreate(player, contentArea, director)
	local challenger = GetWorldManager().SpawnBattleNpcById(3924, contentArea);
	boutState[player.actorId] = { done = false, startTick = nil, challengerId = challenger.actorId };
	challenger:ChangeState(2);
	player:SetMod(modifiersGlobal.MinimumHpLock, 1);
	director:AddMember(player);
	director:AddMember(director);
	director:AddMember(challenger);
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

	local challenger = nil;
	local mobs = area:GetMonsters();
	for i = 1, #mobs do
		if mobs[i] and mobs[i].actorId == state.challengerId then
			challenger = mobs[i];
		end
	end
	-- A dead challenger leaves the roster; battleComplete is on its way.
	if not challenger then
		state.done = true;
		return;
	end

	if not state.startTick then
		state.startTick = tick;
	end
	if not challenger:IsEngaged() then
		allyGlobal.EngageTarget(challenger, owner);
	end

	if (owner:GetHP() <= 1 or tick - state.startTick >= ROUND_LIMIT_TICKS) then
		state.done = true;
		loseGla200Bout(owner);
	end
end

-- Leaving the bout early is a loss; the doors stay open for another try.
function onAbort(player, contentArea, director)
	local state = boutState[player.actorId];
	if state ~= nil then
		state.done = true;
	end
end

function onDestroy()
end
