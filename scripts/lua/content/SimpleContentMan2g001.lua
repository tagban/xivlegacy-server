require ("global")
require ("allyfight")
require ("modifiers")
require ("quests/man/man2g0")

--[[

Beckon of the Elementals: O-App-Pesi's battle against the Spirit of the
Wood in the East Shroud (director QuestDirectorMan2g001). From Gamer
Escape's walkthrough and the Spirit of the Wood's 1.x page: the spirit is
level 28 with 2,930 HP and 2,680 MP, aggressive; Grinnaux, Handeloup and
T'kebbe fight it beside you. A KO puts you back outside Quiver's Hold to
try again.

Every 30 seconds the spirit takes a new aspect (wind, earth or water) and
deals that element; O-App-Pesi stands by to attune a ward against one
(quests/man/man2g0.lua has the rules). Not here yet (STUCK.md): a fallen
ally being replaced after a while. Here the allies can't fall (a 1 HP
floor) instead.

]]

function onCreate(player, contentArea, director)
	allyFight.create(MAN2G0_FIGHT, player, contentArea, director);
	local spot = O_APP_PESI_DUTY_SPOT;
	director:AddMember(contentArea:SpawnActor(O_APP_PESI, "man2g0_o_app_pesi", spot[1], spot[2], spot[3], spot[4]));
end

function onZoneIn(player, contentArea, director)
	player:ChangeMusic(37); -- the 1.x duty theme
end

function onUpdate(tick, area)
	allyFight.update(MAN2G0_FIGHT, tick, area, loseMan2g0Fight);
	updateAspect(tick, area);
end

-- Per player, like allyFight's state; a new try (a new allyFight state)
-- starts over.
local aspects = {};
local TICKS_PER_SECOND = 2;

-- The spirit's aspect every ASPECT_CHANGE_SECONDS, and a ward O-App-Pesi
-- attuned (quest counters) put on the player and the allies.
function updateAspect(tick, area)
	if not area then return end
	local owner = nil;
	for player in area:GetPlayers() do
		if player then owner = owner or player end
	end
	if not owner then return end
	local fight = allyFight.states[owner.actorId];
	if not fight or fight.done then return end
	local state = aspects[owner.actorId];
	if state == nil or state.fight ~= fight then
		state = { fight = fight, nextTick = tick, aspect = 0, casts = 0 };
		aspects[owner.actorId] = state;
	end

	if tick >= state.nextTick then
		for _, m in ipairs(area:GetMonsters()) do
			if m and fight.foeWave[m.actorId] then
				local pick;
				repeat
					pick = math.random(#MAN2G0_ASPECTS);
				until MAN2G0_ASPECTS[pick] ~= state.aspect
				m:SetMod(modifiersGlobal.Aspect, MAN2G0_ASPECTS[pick]);
				if state.aspect ~= 0 then
					owner:SendMessage(0x20, "", "The elemental's aspect has changed!");
				end
				owner:SendMessage(0x20, "", "The Spirit of the Wood takes on the aspect of " .. MAN2G0_ASPECT_NAMES[pick] .. ".");
				state.aspect = MAN2G0_ASPECTS[pick];
				state.nextTick = tick + ASPECT_CHANGE_SECONDS * TICKS_PER_SECOND;
			end
		end
	end

	local quest = owner:GetQuest(110008);
	if quest == nil then return end
	local data = quest:GetData();
	local casts = data:GetCounter(COUNTER_WARD_CASTS);
	if casts > state.casts then
		state.casts = casts;
		local pick = data:GetCounter(COUNTER_WARD_ELEMENT);
		local ward = MAN2G0_WARDS[pick];
		if ward ~= nil then
			owner:SetMod(ward, WARD_POOL);
			for _, a in ipairs(area:GetAllies()) do
				if a and fight.allyIds[a.actorId] then
					a:SetMod(ward, WARD_POOL);
				end
			end
			owner:SendMessage(0x20, "", "You and your allies are warded against " .. MAN2G0_ASPECT_NAMES[pick] .. ".");
		end
	end
end

function onAbort(player, contentArea, director)
	allyFight.abort(player);
end

function onDestroy()
end
