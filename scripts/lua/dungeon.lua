require ("global")
require ("dungeon_spawns")

--[[

The 1.0 dungeons: each run is a copy of its own, for a party or a solo
player (content_instance on the server). Entering builds the copy in the
dungeon's zone, spawns its monsters there (DUNGEON_SPAWNS, from seed 130)
and brings the player's party members in the same zone along; leaving hands
the copy to whoever is still inside, or ends it.

Directors are the client's own for each dungeon (director/instanceraid and
director/occupancy in the client scripts). Entry points are inside each
dungeon by its first door or barrier; exits put you at the nearest camp's
aetherial gate. Retail queued you through NPCs by each entrance (Toto-Rak's
Bloisirant in the South Shroud, for one); until those are scripted, GMs use
!dungeon.

]]

DUNGEONS = {
	totorak = {
		zone = 159, name = "Totorak", content = "SimpleContentDungeonTotorak",
		director = "Occupancy/RaidFst0Dungeon03",
		entry = {885.0, -22.7, 651.0, 1.57},		-- the entrance door
		exit = {154, 991.0, -11.8, 604.0, 0.0},		-- Silent Arbor, South Shroud
	},
	dzemael = {
		zone = 231, name = "Dzemael", content = "SimpleContentDungeonDzemael",
		director = "Occupancy/RaidRoc0Dungeon01",
		entry = {64.0, 181.25, 192.0, 3.14},		-- the Chocobo Stables door
		exit = {143, -517.0, 207.9, 547.0, 0.0},	-- Boulder Downs, Coerthas Central Highlands
	},
	aurum = {
		zone = 245, name = "AurumVale", content = "SimpleContentDungeonAurumVale",
		director = "InstanceRaid/InstanceRaidAurumVale",
		entry = {-686.9, 171.3, 1359.9, 0.0},		-- the Golden Pools' south barrier
		exit = {147, -1.0, 144.1, 1377.0, 0.0},		-- Teriggan's Stand, Coerthas Central Lowlands
	},
	cutters = {
		zone = 246, name = "CuttersCry", content = "SimpleContentDungeonCuttersCry",
		director = "InstanceRaid/InstanceRaidCuttersCry",
		entry = {-1402.0, 252.2, -1455.0, 0.0},	-- the first chamber
		exit = {173, -710.0, 280.4, -2208.0, 0.0},	-- Cutter's Pass, Northern Thanalan
	},
	-- Not a dungeon: Ifrit's battle for the Grand Companies' It Kills with
	-- Fire (Gc?101), entered through Louisoix's aetherial gate at Apkallus
	-- Falls, where his magicks bring you back after.
	embers = {
		zone = 240, name = "BowlOfEmbers", content = "SimpleContentBowlOfEmbers",
		director = "InstanceRaid/InstanceRaidLesserIfrit",
		entry = {2483.0, 248.3, 2194.0, 0.0},		-- the west edge of the Bowl, from cut scene GC010110
		exit = {206, 14.0, 22.2, -1552.0, 0.0},		-- Apkallus Falls, Gridania
	},
	-- Garuda's battle for the Grand Companies' In for Garuda Wakening
	-- (Gc?104), entered through the beastman aetheryte at the north-east tip
	-- of Feathergorge, where you return after.
	howling = {
		zone = 239, name = "HowlingEye", content = "SimpleContentHowlingEye",
		director = "InstanceRaid/InstanceRaidLesserGaruda",
		entry = {1508.0, 302.0, -274.0, -1.16},	-- the bowl's east rim
		exit = {143, 1027.0, 290.8, -137.0, 0.0},	-- Feathergorge, Coerthas Central Highlands
	},
	-- The Grand Companies' assault on Castrum Novum's lunar transmitter
	-- (United We Stand, Gc?106), entered through the aetherial gate in Jagged
	-- Crest Cave, where you return after.
	castrum = {
		zone = 251, name = "CastrumNovum", content = "SimpleContentCastrumNovum",
		director = "InstanceRaid/InstanceRaidBeaconBattle",
		entry = {0.0, 2.0, 1.5, 0.0},				-- the tower's south approach
		exit = {190, -360.0, -15.5, -38.0, -1.57},	-- Jagged Crest Cave, Mor Dhona
	},
	-- Nael van Darnus's battle for the Grand Companies' To Kill a Raven
	-- (Gc?107), reached aboard the Enterprise from the clearing before the
	-- Lotus Stand, where it sets you down after.
	rivenroad = {
		zone = 257, name = "Rivenroad", content = "SimpleContentRivenroad",
		director = "InstanceRaid/InstanceRaidLesserWhiteGeneral",
		entry = {0.0, 0.0, -8.0, 0.0},				-- the Allagan dais's south side
		exit = {206, -202.0, 22.4, -1608.5, 1.57},	-- the clearing before the Lotus Stand, Gridania
	},
}

local function byZone(zoneId)
	for _, d in pairs(DUNGEONS) do
		if d.zone == zoneId then return d end
	end
end

function enterDungeon(player, key)
	local d = DUNGEONS[key];
	if d == nil then return end
	local area = player.CurrentArea:CreateContentArea(player,
		"/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent",
		d.name, d.content, d.director, d.zone);
	if area == nil then return end
	local director = area:GetContentDirector();
	player:AddDirector(director);
	director:StartDirector(false);
	-- Open the director's notice event like the quest duties do; the
	-- director's onEventStarted ends it once the player is in.
	player:KickEvent(director, "noticeEvent", true);
	player:SetLoginDirector(director);
	-- Spawn type 15, a normal zone change: the 0x10 the quest duties use for
	-- same-map warps leaves a cross-zone entry stuck on Now Loading.
	GetWorldManager():DoZoneChangeContentParty(player, area,
		d.entry[1], d.entry[2], d.entry[3], d.entry[4], 15);
end

function leaveDungeon(player)
	local d = byZone(player:GetZoneID());
	player:LeaveContent();
	if d ~= nil then
		GetWorldManager():DoZoneChange(player, d.exit[1], nil, 0, 15, d.exit[2], d.exit[3], d.exit[4], d.exit[5]);
	end
end

-- A content script's onCreate: the dungeon's monsters, into this copy.
function spawnDungeon(player, contentArea, director, zoneId)
	director:AddMember(player);
	local ranges = DUNGEON_SPAWNS[zoneId];
	if ranges == nil then return end
	for _, range in ipairs(ranges) do
		for id = range[1], range[2] do
			GetWorldManager().SpawnBattleNpcById(id, contentArea);
		end
	end
end
