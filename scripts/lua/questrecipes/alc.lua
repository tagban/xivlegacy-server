-- Alchemists' Guild quest recipes: our own rows, not retail data (see
-- questrecipes.lua). Alchemist = class 35.

-- Alc200: Faustigeant's medicine for Damielliot, from the reagent Nomomo
-- sells at Camp Black Brush and eye drops, as the journal lists.
QuestRecipes.add({
	quest = 110420, sequences = { 10 },
	resultItemID = 11000077, resultQuantity = 1,
	classId = 35, level = 18,
	crystalId1 = 1000007, crystalQuantity1 = 2,       -- lightning shard
	crystalId2 = 1000008, crystalQuantity2 = 1,       -- water shard
	materials = { 11000076, 3020401 },                -- mummified mole, eye drops
});

-- Alc306: the salve from the poultice Damielliot gives you with its
-- recipe; it needs nothing else.
QuestRecipes.add({
	quest = 110422, sequences = { 10 },
	resultItemID = 11000079, resultQuantity = 1,
	classId = 35, level = 34,
	crystalId1 = 1000007, crystalQuantity1 = 4,       -- lightning shard
	crystalId2 = 1000008, crystalQuantity2 = 3,       -- water shard
	materials = { 11000078 },                         -- Frondale's poultice
});
