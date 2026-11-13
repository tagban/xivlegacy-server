--[[

Dungeon boss chests: what the chest after each boss holds.

A chest appears in a boss's room when the boss falls in a dungeon copy
(map-server runtime/dungeon_chest.rs). Opening it hands out every item in
its list:

	{ item_id }                    one, to a random player of the copy
	{ item_id, count = n }         n of it, to a random player of the copy
	{ item_id, quest = quest_id }  one to every player of the copy who is
	                               on that quest and doesn't hold it yet

Keys are the boss's bnpc id (dungeon_fight.rs BOSS_ROOMS). An edit here
needs no rebuild; it takes effect when the map server restarts.

No archived 1.0 source lists what the dungeon chests held, apart from
Enchiridion (the client's own chest script). The gear below was picked by
rule, for the user to review (research/dungeon-chest-candidates.md in the
host notes): gear for several classes, at the dungeon's level to two above
(the dungeon's level = its weakest monsters', 50 at most), that no monster,
shop, recipe, quest or leve gives, matched to the dungeon's theme.

--]]

DUNGEON_CHESTS = {

	-- Toto-Rak (copy, level 35 monsters). Only two pieces fit the rule at
	-- level 35-37, so all three chests hold the same pair.
	[3457] = { boss = "Antares",
		{ 8081117 },	-- Engineer's Leggings (35, DoW + DoH/DoL)
		{ 8070719 },	-- Venerer's Bracers (35, ARC BRD)
	},
	[3458] = { boss = "Sargas",
		{ 8081117 },	-- Engineer's Leggings
		{ 8070719 },	-- Venerer's Bracers
	},
	[3459] = { boss = "Shaula",
		{ 8081117 },	-- Engineer's Leggings
		{ 8070719 },	-- Venerer's Bracers
	},

	-- Dzemael Darkhold (level 50): Explorer's (the old mine's explorers),
	-- Stonewall (tank) and Blessed (healer) jewelry.
	[2000] = { boss = "Batraal",
		{ 10011244, quest = 110868 },	-- Enchiridion, for A Relic Reborn
		{ 8030349 },	-- Explorer's Tabard (GLA MRD LNC PLD WAR DRG)
		{ 9040063 },	-- Stonewall Choker (all)
		{ 9030057 },	-- Blessed Earrings (all)
	},
	[2001] = { boss = "All-seeing Eye",
		{ 8050242 },	-- Explorer's Breeches (DoW)
		{ 8090006 },	-- Explorer's Belt (all)
		{ 9030056 },	-- Stonewall Earrings (all)
		{ 9050066 },	-- Blessed Ring (all)
	},
	[2002] = { boss = "Soulgazer",
		{ 8080717 },	-- Explorer's Moccasins (DoW)
		{ 8080116 },	-- Explorer's Sabatons (GLA MRD PLD WAR)
		{ 9050065 },	-- Stonewall Ring (all)
		{ 9030063 },	-- White Ravens (all)
	},

	-- Aurum Vale (level 50): the gold-hungry Vale gets the sellswords'
	-- Mercenary's (DoW) and the Harlequin's (DoM).
	[2300] = { boss = "Coincounter",
		{ 8030823 },	-- Mercenary's Acton (DoW)
		{ 8011521 },	-- Mercenary's Pot Helm (DoW)
		{ 8030817 },	-- Harlequin's Acton (DoM)
		{ 8011903 },	-- Harlequin's Cap (DoM)
	},
	[2301] = { boss = "Miser's Mistress",
		{ 8051121 },	-- Mercenary's Slops (DoW)
		{ 8070811 },	-- Mercenary's Mitts (DoW)
		{ 8081122 },	-- Mercenary's Leggings (DoW)
		{ 8051016 },	-- Harlequin's Tights (DoM)
		{ 8090507 },	-- Harlequin's Belt (DoM)
	},

	-- Cutter's Cry (level 50), under the Sagolii desert: Sipahi (DoW) and
	-- Mage's (DoM).
	[2600] = { boss = "Myrmidon Princess",
		{ 8011323 },	-- Sipahi Turban (DoW)
		{ 8070526 },	-- Sipahi Gloves (DoW)
		{ 8070915 },	-- Spiked Armguards (DoW)
		{ 8031421 },	-- Mage's Halfrobe (DoM)
		{ 9040062 },	-- Mage's Choker (all)
	},
	[2601] = { boss = "Chimera",
		{ 8030725 },	-- Sipahi Shirt (DoW)
		{ 8050727 },	-- Sipahi Sarouel (DoW)
		{ 8080525 },	-- Sipahi Crakows (DoW)
		{ 9030055 },	-- Mage's Earrings (all)
		{ 9050064 },	-- Mage's Ring (all)
	},
};

-- The chest's loot by the chest npc's unique id ("dungeon_chest_<bnpc>").
function DungeonChestLoot(uniqueId)
	local bnpc = tonumber(string.match(uniqueId or "", "^dungeon_chest_(%d+)$"));
	return bnpc and DUNGEON_CHESTS[bnpc] or {};
end
