require ("global")
require ("quests/exc/exc306")

-- Exc306 Captain's Orders: the Consortium alehold, staged in the hold of the
-- Rhotano Sea ship (zone 192) as Exc300's den is. One "???" (sparkle
-- 1080024, a quest talk: exc30630) on floor walked in the client for
-- Pgl300; the quest ends the content when it is found.

function onCreate(player, contentArea, director)
	director:AddMember(player);
	director:AddMember(director);
	director:AddMember(contentArea:SpawnActor(ENPC_BARREL, "exc306_barrel", 1824.8, -61.65, 1814.4, 0.0));
end

function onZoneIn(player, contentArea, director)
end

function onUpdate(tick, area)
end

-- Leaving early needs nothing: the circle by Waekbyrt stays open.
function onAbort(player, contentArea, director)
end

function onDestroy()
end
