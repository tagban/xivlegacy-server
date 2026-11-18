require ("global")
require ("modifiers")

-- Thornmarch (zone 238, dungeon.lua "thornmarch") for Louisoix's A Feast of
-- Fools (Sum6m0): Good King Moggle Mog XII and seven corrupted moogles in
-- the moogle ring. Their fall empties the content roster, which fires
-- "battleComplete" to the director (InstanceRaidDarkMoogle).

COURT = {1925, 1926, 1927, 1928, 1929, 1930, 1931, 1932};	-- the seven moogles, then the king

function onCreate(player, contentArea, director)
	director:AddMember(player);
	for _, id in ipairs(COURT) do
		director:AddMember(GetWorldManager().SpawnBattleNpcById(id, contentArea));
	end
	-- The player can't die in content yet (no death/return flow there).
	player:SetMod(modifiersGlobal.MinimumHpLock, 1);
end

function onZoneIn(player, contentArea, director)
end

-- The court's moves (1.0, archived Gamer Escape move pages): each moogle has
-- a signature move, and Good King Moggle Mog XII takes up a moogle's move
-- once that moogle falls. Every moogle uses Mogdive (on their lists).
-- Keys are the court's model class names (actor:GetClassName()).
SIGNATURE = {
	MoogleDarkTanker   = 23415,	-- Whisker Bash (Whiskerwall Kupdi Koop)
	MoogleDarkAttacker = 23413,	-- 100 Needles
	MoogleDarkSniper   = 23420,	-- Moogle Eye Shot (Woolywart Kupqu Kogi)
	MoogleDarkHealer   = 23417,	-- Moogle-Go-Round
	MoogleDarkNuker    = 23421,	-- Pom Flare (Pukla Puki the Pomburner)
	MoogleDarkBuffer   = 23422,	-- Maximoogle (Puksi Piko the Shaggysong)
	MoogleDarkDebuffer = 23423,	-- Mognesia (Pukna Pako the Tailturner)
};
KING = "MoogleDarkKing";
-- Memento Moogle: the king's opening move, stronger the more of his court
-- still stands (1.0: one surviving moogle could wipe a party). One command
-- per strength: none left, 1-2, 3-4, 5 or more.
MEMENTO = {23424, 23451, 23452, 23453};

-- Per king (his actor id): court moogles seen alive, and whether he opened.
court = {};

function onUpdate(tick, area)
	local king = nil;
	local now = {};
	local standing = 0;
	for _, mob in ipairs(area:GetMonsters()) do
		local name = mob:GetClassName();
		if name == KING then
			king = mob;
		elseif SIGNATURE[name] ~= nil then
			now[name] = true;
			standing = standing + 1;
		end
	end
	if king == nil then
		return;
	end
	local key = king:GetActorClassId();	-- the live actor id
	local state = court[key];
	if state == nil then
		state = {alive = now, opened = false};
		court[key] = state;
	end
	-- A moogle seen alive last tick and gone now has fallen: the king takes its move.
	for name, _ in pairs(state.alive) do
		if not now[name] then
			king:LearnMonsterMove(SIGNATURE[name]);
		end
	end
	state.alive = now;
	if not state.opened and king:IsEngaged() then
		state.opened = true;
		local tier = 1;
		if standing >= 5 then tier = 4 elseif standing >= 3 then tier = 3 elseif standing >= 1 then tier = 2 end
		king:UseMonsterMove(MEMENTO[tier]);
	end
end

function onAbort(player, contentArea, director)
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
end

function onDestroy()
end
