require ("global")
require ("modifiers")
require ("quests/man/man406")

-- Futures Perfect, Mor Dhona: the children's cave (SEQ_045), after the
-- airship scenes. Its own duty: QuestDirectorMan40601 finishes the patrol
-- fight (SimpleContentMan40601) and moves you in here, because a director
-- has no handle on the content area it runs in, so it can't warp within
-- it. The children talk (the Echo's vision); the way out at the cave
-- mouth is the quest's (onPush, CAVE_EXIT_TRIGGER), which ends this duty.

-- The cave (a passage under the hills, floor about y 54-55, climbing west
-- and north to its mouth); the children, and the way out at the mouth.
CAVE_CHILDREN = {
	{ class = 1000957, name = "man406_shuddering_child",	x = 306.0, y = 54.5, z = -796.0, rot = -1.57 },
	{ class = 1000958, name = "man406_cowering_child",		x = 312.0, y = 54.4, z = -796.0, rot = -1.57 },
	{ class = 1000959, name = "man406_shivering_child",		x = 306.0, y = 53.7, z = -784.0, rot = -2.36 },
	{ class = 1000960, name = "man406_cried_out_child",		x = 312.0, y = 53.9, z = -790.0, rot = -1.57 },
	{ class = 1000961, name = "man406_terrified_child",		x = 300.0, y = 53.7, z = -788.0, rot = 3.14 },
};
CAVE_EXIT = { x = 225.0, y = 69.2, z = -762.0 };

function onCreate(player, contentArea, director)
	director:AddMember(player);
	director:AddMember(director);
	for _, child in ipairs(CAVE_CHILDREN) do
		director:AddMember(contentArea:SpawnActor(child.class, child.name, child.x, child.y, child.z, child.rot));
	end
	director:AddMember(contentArea:SpawnActor(CAVE_EXIT_TRIGGER, "man406_cave_exit", CAVE_EXIT.x, CAVE_EXIT.y, CAVE_EXIT.z, 0.0));
	player:SetMod(modifiersGlobal.MinimumHpLock, 1);
end

function onZoneIn(player, contentArea, director)
	player:ChangeMusic(37); -- the 1.x duty theme
end

function onUpdate(tick, area)
end

function onAbort(player, contentArea, director)
end

function onDestroy()
end
