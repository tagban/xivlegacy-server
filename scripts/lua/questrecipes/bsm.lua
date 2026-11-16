--[[

Blacksmiths' Guild quest recipes (our rows, not retail; see questrecipes.lua).

Bsm200 (110320): the gramophone case on SEQ_010 and the trembler on SEQ_015.
Bsm306 (110322): the earplug mold on SEQ_005.

Materials are ordinary Blacksmith stock near each quest's level:
	10002001 Bronze Nugget, 10002011 Bronze Ingot, 10002012 Iron Ingot,
	10008205 Ash Lumber; shards 1000003 Fire, 1000005 Wind, 1000006 Earth.

]]

-- Gramophone case: two bronze ingots and a length of ash.
QuestRecipes.add({
	quest = 110320, sequences = { 10 },
	resultItemID = 11000004, resultQuantity = 1,
	classId = 30, level = 18,
	crystalId1 = 1000003, crystalQuantity1 = 3,
	crystalId2 = 1000006, crystalQuantity2 = 2,
	materials = { 10002011, 10002011, 10008205 },
});

-- Trembler: a bronze ingot and two nuggets for the hammer and clapper.
QuestRecipes.add({
	quest = 110320, sequences = { 15 },
	resultItemID = 11000005, resultQuantity = 1,
	classId = 30, level = 20,
	crystalId1 = 1000003, crystalQuantity1 = 3,
	crystalId2 = 1000005, crystalQuantity2 = 2,
	materials = { 10002011, 10002001, 10002001 },
});

-- Earplug mold: two bronze ingots around an iron core.
QuestRecipes.add({
	quest = 110322, sequences = { 5 },
	resultItemID = 11000050, resultQuantity = 1,
	classId = 30, level = 35,
	crystalId1 = 1000003, crystalQuantity1 = 5,
	crystalId2 = 1000006, crystalQuantity2 = 4,
	materials = { 10002011, 10002011, 10002012 },
});
