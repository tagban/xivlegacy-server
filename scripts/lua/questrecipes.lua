--[[

Quest recipes: our own rows, not retail recipe data.

The crafting guild quests of 1.23b ask for story items (a gramophone case,
a bronze earplug mold, a quest dish...) that are dummy items with no recipe
in gamedata_recipes; the retail game made them through its own quest path.
Here each such item gets a recipe from the guild's ordinary materials and
crystals, near the quest's level, that works only while the player holds
the quest at one of the listed sequences. CraftCommand offers them next to
the retail recipes for the same materials.

Each guild keeps its rows in questrecipes/<guild>.lua:

	QuestRecipes.add({
		quest = 110320, sequences = { 10 },   -- Bsm200, while on SEQ_010
		resultItemID = 11000004, resultQuantity = 1,
		classId = 30, level = 18,
		crystalId1 = 1000003, crystalQuantity1 = 2,
		crystalId2 = 0, crystalQuantity2 = 0,
		materials = { 10001006, 10001006, 10008001 },
	});

]]

QuestRecipes = { list = {} };

local MATERIAL_SLOTS = 8;

local function sortedMaterials(mats)
	local out = {};
	for i = 1, #mats do
		if (mats[i] ~= nil and mats[i] ~= 0) then out[#out + 1] = mats[i]; end
	end
	table.sort(out);
	return out;
end

local function getMaterials(self)
	local out = {};
	for i = 1, MATERIAL_SLOTS do out[i] = self.materials[i] or 0; end
	return out;
end

function QuestRecipes.add(r)
	r.resultQuantity = r.resultQuantity or 1;
	r.crystalId1, r.crystalQuantity1 = r.crystalId1 or 0, r.crystalQuantity1 or 0;
	r.crystalId2, r.crystalQuantity2 = r.crystalId2 or 0, r.crystalQuantity2 or 0;
	r.facility = r.facility or 0;
	r.isQuestRecipe = true;
	r.key = table.concat(sortedMaterials(r.materials), ",");
	r.GetMaterials = getMaterials;
	QuestRecipes.list[#QuestRecipes.list + 1] = r;
end

-- Whether the player holds the recipe's quest at one of its sequences.
function QuestRecipes.isOpen(player, r)
	if (not player:HasQuest(r.quest)) then return false; end
	local seq = player:GetQuest(r.quest):GetSequence();
	for _, s in ipairs(r.sequences) do
		if (s == seq) then return true; end
	end
	return false;
end

-- The quest recipes these placed materials (item ids, zeros for empty
-- slots, in any order) make for this player right now.
function QuestRecipes.forMaterials(player, mats)
	local key = table.concat(sortedMaterials(mats), ",");
	local out = {};
	if (key == "") then return out; end
	for _, r in ipairs(QuestRecipes.list) do
		if (r.key == key and QuestRecipes.isOpen(player, r)) then out[#out + 1] = r; end
	end
	return out;
end

for _, guild in ipairs({ "wdk", "bsm", "gld", "tan", "wvr", "alc", "cul", "min", "hrv", "fsh" }) do
	if (package.searchpath("questrecipes/" .. guild, package.path) ~= nil) then
		require("questrecipes/" .. guild);
	end
end
