-- Carpenters' Guild quest recipes: our own rows, not retail data (see
-- questrecipes.lua). Carpenter = class 29.

-- Wdk200: a bow from the branch you picked up at Quarrymill, with lumber
-- and yarn as for an elm shortbow. Wybir wants the supple one.
local WDK200_BOWS = {
	{ branch = 11000062, bow = 11000058 }, -- blooming
	{ branch = 11000063, bow = 11000059 }, -- supple
	{ branch = 11000064, bow = 11000060 }, -- sturdy
};
for _, b in ipairs(WDK200_BOWS) do
	QuestRecipes.add({
		quest = 110300, sequences = { 20 },
		resultItemID = b.bow, resultQuantity = 1,
		classId = 29, level = 18,
		crystalId1 = 1000005, crystalQuantity1 = 1,   -- wind shard
		crystalId2 = 1000004, crystalQuantity2 = 4,   -- ice shard
		materials = { b.branch, 10008205, 10005302 }, -- ash lumber, cotton yarn
	});
end

-- Wdk306: a fairweather fetish for the children in the Acorn Orchard.
QuestRecipes.add({
	quest = 110302, sequences = { 10 },
	resultItemID = 11000065, resultQuantity = 1,
	classId = 29, level = 34,
	crystalId1 = 1000005, crystalQuantity1 = 8,       -- wind shard
	materials = { 10008207, 10005302, 10009215 },     -- walnut lumber, cotton yarn, linseed oil
});
