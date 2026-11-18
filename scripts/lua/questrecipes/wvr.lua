-- Weavers' Guild quest recipes: our own rows, not retail data (see
-- questrecipes.lua). Weaver = class 34.

-- Wvr200: mend Chuchumu's red riding hood from the ripped one Deaustie
-- hands over, as the journal lists: cotton cloth, red dye, cotton yarn.
QuestRecipes.add({
	quest = 110400, sequences = { 12 },
	resultItemID = 11000054, resultQuantity = 1,
	classId = 34, level = 18,
	crystalId1 = 1000007, crystalQuantity1 = 3,       -- lightning shard
	crystalId2 = 1000005, crystalQuantity2 = 2,       -- wind shard
	materials = { 11000055, 10005005, 10010719, 10005302 }, -- ripped hood, undyed cotton cloth, red dye, cotton yarn
});

-- Wvr306: a pair of luxurious gloves from each strand of Thanalan spider
-- silk Chuchumu gives at the Copperbell Mines, with velveteen and cotton
-- yarn; ten pairs, one strand at a time.
QuestRecipes.add({
	quest = 110402, sequences = { 9 },
	resultItemID = 11000056, resultQuantity = 1,
	classId = 34, level = 34,
	crystalId1 = 1000007, crystalQuantity1 = 5,       -- lightning shard
	crystalId2 = 1000005, crystalQuantity2 = 3,       -- wind shard
	materials = { 11000057, 10005015, 10005302 },     -- spider silk, undyed velveteen, cotton yarn
});
