require ("global")

-- Hildibrand: the givers hand over a "Wanted" poster (or, for Etc5l3,
-- the dossier) and say to log out in an inn with it. Sleeping in that
-- inn's bed with the item starts the quest, ready on the next login.
local LIMSA_BED, GRIDANIA_BED, ULDAH_BED = 1200378, 1200379, 1200380;
local ITEM_WANTED_GAUWYN, ITEM_HILDIBRAND_DOSSIER = 10011243, 10011252;
local HILDIBRAND_INN_STARTS = {
	{ quest = 110849, item = ITEM_WANTED_GAUWYN, beds = {ULDAH_BED}, after = {110828, 110838, 110848} }, -- The Usual Suspect
	{ quest = 110829, item = ITEM_WANTED_GAUWYN, beds = {GRIDANIA_BED}, after = {110849} },             -- In Plain Sight
	{ quest = 110839, item = ITEM_WANTED_GAUWYN, beds = {LIMSA_BED}, after = {110829} },                -- Private Eyes
	{ quest = 110841, item = ITEM_HILDIBRAND_DOSSIER, beds = {LIMSA_BED, GRIDANIA_BED, ULDAH_BED}, after = {110840} }, -- Prophecy Inspection
};

local function contains(list, value)
	for _, v in ipairs(list) do
		if (v == value) then return true; end
	end
	return false;
end

local function startHildibrandQuests(player, npc)
	local bed = npc:GetActorClassId();
	for _, start in ipairs(HILDIBRAND_INN_STARTS) do
		if (contains(start.beds, bed) and player:CanAcceptQuest(start.quest)
			and player:GetItemPackage(INVENTORY_NORMAL):HasItem(start.item)) then
			for _, prereq in ipairs(start.after) do
				if (player:IsQuestCompleted(prereq)) then
					player:AddQuest(start.quest);
					break;
				end
			end
		end
	end
end

function init(npc)
	return false, false, 0, 0;	
end

function onEventStarted(player, npc, triggerName)

	choice = callClientFunction(player, "askLogout", player);
	
	if (choice == 2 or choice == 3) then
		startHildibrandQuests(player, npc);
	end

	if (choice == 2) then
		player:SetSleeping();
		player:QuitGame();
	elseif (choice == 3) then
		player:SetSleeping();
		player:Logout();
	elseif (choice == 4) then
		player:SendMessage(33, "", "Heck the bed");
	end
	
	player:EndEvent();
	
end
