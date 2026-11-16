-- Culinarians' Guild quest recipes: our own rows, not retail recipe data.

-- Cul200: Prudentia's (or Pulmia's) piping hot pie crust, from the recipe
-- she hands you (the journal lists these five ingredients). SEQ_015.
QuestRecipes.add({
	quest = 110440, sequences = { 15 },
	resultItemID = 11000069, resultQuantity = 1, -- Piping Hot Pie Crust
	classId = 36, level = 18,
	crystalId1 = 1000003, crystalQuantity1 = 4, -- Fire Shard
	materials = {
		3011524, -- Sunset Wheat Flour
		3011509, -- Cinnamon
		3011502, -- Salted Butter
		3011529, -- Table Salt
		3010609, -- Mineral Water
	},
});

-- Cul306: the foulbelly meatball (queer-smelling meat and sweet-smelling
-- spice from the cooks, and a button mushroom), then the devilbelly
-- meatball (two devilshrooms and the foulbelly meatball). SEQ_050.
QuestRecipes.add({
	quest = 110442, sequences = { 50 },
	resultItemID = 11000073, resultQuantity = 1, -- Foulbelly Meatball
	classId = 36, level = 34,
	crystalId1 = 1000009, crystalQuantity1 = 1, -- Fire Crystal
	materials = {
		11000074, -- Queer-smelling Meat
		11000075, -- Sweet-smelling Spice
		3011406,  -- Button Mushroom
	},
});
QuestRecipes.add({
	quest = 110442, sequences = { 50 },
	resultItemID = 11000071, resultQuantity = 1, -- Devilbelly Meatball
	classId = 36, level = 35,
	crystalId1 = 1000009, crystalQuantity1 = 1, -- Fire Crystal
	crystalId2 = 1000014, crystalQuantity2 = 1, -- Water Crystal
	materials = {
		11000072, -- Devilshroom
		11000072,
		11000073, -- Foulbelly Meatball
	},
});
