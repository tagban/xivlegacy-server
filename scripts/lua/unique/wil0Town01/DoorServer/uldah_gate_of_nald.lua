require ("global")

-- The Gate of Nald, Ul'dah's way out to Central Thanalan (#356). The town
-- layout (wil_w0_twn01, layout 421) bakes it in as isgrp_002836 with
-- open/clos schedules and draws it closed by default, with collision.
-- Binding a DoorServer to it with isOpen = true makes the client run its
-- open schedule, so players can walk out of the city.
function init(npc)
	return false, false, 0, 0, 421, 2836, true;
end
