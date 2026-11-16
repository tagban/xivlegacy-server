-- Leatherworkers' Guild quest recipes: our own rows, not retail data (see
-- questrecipes.lua). Leatherworker = class 33.

-- Tan200: the Wood Wailers' armor mended with aldgoat leather, first from
-- the damaged armor Lalatta hands over, then remade from the remnants.
QuestRecipes.add({
	quest = 110380, sequences = { 20 },
	resultItemID = 11000045, resultQuantity = 1,
	classId = 33, level = 18,
	crystalId1 = 1000006, crystalQuantity1 = 3,       -- earth shard
	crystalId2 = 1000005, crystalQuantity2 = 2,       -- wind shard
	materials = { 11000044, 10007126, 10007508 },     -- damaged armor, aldgoat leather, mole sinew cord
});
QuestRecipes.add({
	quest = 110380, sequences = { 33 },
	resultItemID = 11000045, resultQuantity = 1,
	classId = 33, level = 18,
	crystalId1 = 1000006, crystalQuantity1 = 3,
	crystalId2 = 1000005, crystalQuantity2 = 2,
	materials = { 11000046, 10007126, 10007508 },     -- armor remnants, aldgoat leather, mole sinew cord
});

-- Tan300: a Fen-Yll birkin bag of toad leather and brass for Clearwater Lake.
QuestRecipes.add({
	quest = 110381, sequences = { 25 },
	resultItemID = 11000047, resultQuantity = 1,
	classId = 33, level = 28,
	crystalId1 = 1000006, crystalQuantity1 = 4,
	crystalId2 = 1000005, crystalQuantity2 = 3,
	materials = { 10007113, 10003012, 10007501 },     -- toad leather, brass ingot, antelope sinew cord
});

-- Tan306: the damaged Fen-Yll boots mended with boar leather.
QuestRecipes.add({
	quest = 110382, sequences = { 27 },
	resultItemID = 11000049, resultQuantity = 1,
	classId = 33, level = 34,
	crystalId1 = 1000005, crystalQuantity1 = 5,
	crystalId2 = 1000006, crystalQuantity2 = 3,
	materials = { 11000048, 10007116, 10007502 },     -- damaged boots, boar leather, hippogryph sinew cord
});
