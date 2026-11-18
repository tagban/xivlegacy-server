require ("global")
require ("quests/exc/exc300")

-- Exc300 Two-man Crew: the Krakens' den, staged in the hold of the Rhotano
-- Sea ship (zone 192) as Pgl300's Misery is. Three papers to read (sparkles
-- 1080021-1080023, quest talks: trialObject 1-3) on floor walked in the
-- client for Pgl300. The quest ends the content once the third is read.

function onCreate(player, contentArea, director)
	local data = nil;
	local quest = player:GetQuest(110101);
	if (quest ~= nil) then
		data = quest:GetData();
	end
	director:AddMember(player);
	director:AddMember(director);
	local spots = {
		{ ENPC_DEN_LOG, "exc300_den_log", 1824.8, -61.65, 1814.4 },
		{ ENPC_DEN_BILL, "exc300_den_bill", 1818.5, -61.65, 1806.8 },
		{ ENPC_DEN_PARCHMENT, "exc300_den_parchment", 1824.9, -59.39, 1800.0 },
	};
	for i, spot in ipairs(spots) do
		-- A paper read on an earlier try stays gone.
		if (data == nil or not data:GetFlag(PAPERS[i].flag)) then
			director:AddMember(contentArea:SpawnActor(spot[1], spot[2], spot[3], spot[4], spot[5], 0.0));
		end
	end
end

function onZoneIn(player, contentArea, director)
	player:ChangeMusic(37); -- the 1.x duty theme
end

function onUpdate(tick, area)
end

-- Leaving early needs nothing: the door stays open and read papers stay read.
function onAbort(player, contentArea, director)
end

function onDestroy()
end
