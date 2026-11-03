require ("global")
require ("modifiers")
-- allyGlobal.EngageTarget opens each foe on the player.
require ("ally")
require ("quests/pgl/pgl300")

-- Pgl300 Here There Be Pirates: the Misery's hold, staged in the hold of
-- the Rhotano Sea ship (zone 192). A chest and a door to search (sparkles
-- 1080017-1080018, quest talks; the door is the doorway beside the drop)
-- and three Kraken deckhands (seed 295, bnpcs 3946-3948) idling
-- about the hold. All stand on floor walked in the client. Searching both, or striking
-- first, sets them on the player; killing the last one leaves the content
-- without hostiles, which fires "battleComplete" to QuestDirectorPgl30001.
-- The player can't die in content yet, so losing is being pinned at the
-- 1-HP floor (or the fight running out of time); the content ends that
-- itself and sets the player down by the gangway.

TICKS_PER_SECOND = 2;
FIGHT_LIMIT_TICKS = 8 * 60 * TICKS_PER_SECOND;
FOES = { 3946, 3947, 3948 };

-- Per-player fight state (the VM is cached per script path).
fightState = {};

function onCreate(player, contentArea, director)
	local state = { done = false, alarmed = false, startTick = nil, foeIds = {} };
	director:AddMember(player);
	director:AddMember(director);
	director:AddMember(contentArea:SpawnActor(ENPC_HOLD_CHEST, "pgl300_hold_chest", 1824.8, -61.65, 1814.4, 0.0));
	director:AddMember(contentArea:SpawnActor(ENPC_HOLD_DOOR, "pgl300_hold_door", 1828.2, -61.65, 1816.3, 0.0));
	for i = 1, #FOES do
		local foe = GetWorldManager().SpawnBattleNpcById(FOES[i], contentArea);
		director:AddMember(foe);
		state.foeIds[foe.actorId] = true;
	end
	fightState[player.actorId] = state;
	player:SetMod(modifiersGlobal.MinimumHpLock, 1);
end

function onZoneIn(player, contentArea, director)
	player:ChangeMusic(37); -- the 1.x duty theme
end

local function searchesDone(player)
	local quest = player:GetQuest(110061);
	if (quest == nil) then
		return false;
	end
	local data = quest:GetData();
	return data:GetFlag(FLAG_SEARCHED_CHEST) and data:GetFlag(FLAG_SEARCHED_DOOR);
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
	local foes = {};
	local mobs = area:GetMonsters();
	for i = 1, #mobs do
		local mob = mobs[i];
		if mob and state.foeIds[mob.actorId] then
			alive = alive + 1;
			foes[#foes + 1] = mob;
			if mob:IsEngaged() then
				state.alarmed = true;
			end
		end
	end
	-- The last foe down leaves the roster; battleComplete is on its way.
	if alive == 0 then
		state.done = true;
		return;
	end

	if not state.alarmed and searchesDone(owner) then
		state.alarmed = true;
		owner:SendMessage(0x20, "", "The deckhands have spotted you!");
	end
	if not state.alarmed then return end
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
		losePgl300Hold(owner, timedOut);
	end
end

-- Leaving the hold early is a loss; the gangway stays open for another try.
function onAbort(player, contentArea, director)
	local state = fightState[player.actorId];
	if state ~= nil then
		state.done = true;
	end
end

function onDestroy()
end
