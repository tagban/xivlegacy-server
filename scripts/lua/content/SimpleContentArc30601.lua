require ("global")
require ("modifiers")
-- allyGlobal.EngageTarget opens each foe on the player.
require ("ally")
require ("quests/arc/arc306")

-- Arc306 There Can Be Only One: Siward and his yarzons in the Central
-- Shroud (bnpcs 3952-3955). Siward has no battle class of his own, so he is
-- a hostile humanoid class wearing his look (class 1000342) and his name.
-- When he falls the yarzons go with him; the content is then without
-- hostiles, which fires "battleComplete" to QuestDirectorArc30601.
-- The player can't die in content yet, so losing is being pinned at the
-- 1-HP floor (or the fight running out of time); the content ends that
-- itself and sets the player down in the wood.

TICKS_PER_SECOND = 2;
FIGHT_LIMIT_TICKS = 8 * 60 * TICKS_PER_SECOND;
SIWARD = 3952;
SIWARD_LOOK = 1000342;
YARZONS = { 3953, 3954, 3955 };

-- Per-player fight state (the VM is cached per script path).
fightState = {};

function onCreate(player, contentArea, director)
	local state = { done = false, startTick = nil, siwardId = nil, foeIds = {} };
	director:AddMember(player);
	director:AddMember(director);
	local siward = GetWorldManager().SpawnBattleNpcById(SIWARD, contentArea, SIWARD_LOOK, "Siward");
	siward:ChangeState(2);
	director:AddMember(siward);
	state.siwardId = siward.actorId;
	state.foeIds[siward.actorId] = true;
	for i = 1, #YARZONS do
		local foe = GetWorldManager().SpawnBattleNpcById(YARZONS[i], contentArea);
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

	local siwardUp = false;
	local foes = {};
	local mobs = area:GetMonsters();
	for i = 1, #mobs do
		local mob = mobs[i];
		if mob and state.foeIds[mob.actorId] then
			table.insert(foes, mob);
			if mob.actorId == state.siwardId then
				siwardUp = true;
			end
		end
	end
	-- The roster can lag the spawns by a tick or two: Siward counts as down
	-- only once he has been seen.
	if siwardUp then
		state.siwardSeen = true;
	end
	-- Siward down: the yarzons go with him, and battleComplete follows.
	if state.siwardSeen and not siwardUp then
		state.done = true;
		for i = 1, #foes do
			foes[i]:Die();
		end
		return;
	end
	for i = 1, #foes do
		if not foes[i]:IsEngaged() then
			allyGlobal.EngageTarget(foes[i], owner);
		end
	end

	if not state.startTick then
		state.startTick = tick;
	end
	local timedOut = tick - state.startTick >= FIGHT_LIMIT_TICKS;
	if (owner:GetHP() <= 1 or timedOut) then
		state.done = true;
		loseArc306Fight(owner, timedOut);
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
