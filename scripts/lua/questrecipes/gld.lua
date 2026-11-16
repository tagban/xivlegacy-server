--[[

Goldsmiths' Guild quest recipes (our rows, not retail; see questrecipes.lua).

Gld200 (110360): Z'ssapa's brooch, from the Amajina silver nuggets Z'ssapa
	hands over on SEQ_010, made while looking for a muse (SEQ_030) or once
	the ideal sketch is done (SEQ_032).
Gld306 (110362): the Heartstrike replica on SEQ_015, from the three
	materials Sence hands over on SEQ_010 (normal bag, so they can be placed).

Ordinary Goldsmith stock used: 10003012 Brass Ingot, 10004103 Sphene;
shards 1000003 Fire, 1000005 Wind.

]]

-- Z'ssapa's brooch: the quest's silver nuggets on a brass setting with a sphene.
QuestRecipes.add({
	quest = 110360, sequences = { 30, 32 },
	resultItemID = 11000108, resultQuantity = 1,
	classId = 32, level = 20,
	crystalId1 = 1000005, crystalQuantity1 = 3,
	crystalId2 = 1000003, crystalQuantity2 = 3,
	materials = { 11000121, 10003012, 10004103 },
});

-- Heartstrike replica: pure metal ore, brilliant glass shards and silverwater.
QuestRecipes.add({
	quest = 110362, sequences = { 15 },
	resultItemID = 11000116, resultQuantity = 1,
	classId = 32, level = 35,
	crystalId1 = 1000005, crystalQuantity1 = 5,
	crystalId2 = 1000003, crystalQuantity2 = 5,
	materials = { 11000117, 11000118, 11000119 },
});
