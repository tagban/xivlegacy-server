--[[

PopulaceChocoboLender Script

Functions:

eventTalkWelcome(player) - Start Text
eventAskMainMenu(player, curLevel, hasFundsForRent, isPresentChocoboIssuance, isSummonMyChocobo, isChangeBarding, currentChocoboWare) - Shows the main menu
eventTalkMyChocobo(player) - Starts the cutscene for getting a chocobo
eventSetChocoboName(true) - Opens the set name dialog
eventAfterChocoboName(player) - Called if player done naming chocobo, shows cutscene, returns state and waits to teleport outside city.
eventCancelChocoboName(player) - Called if player cancels naming chocobo, returns state. 
eventTalkStepBreak(player) - Finishes talkTurn and says a goodbye

Notes:

* Rent price and time seems to be hardcoded into the client. Price is always 800gil and time is 10m.
* The issuance scenes *require* the actor with class id `1080101` (sys_chocoview) to be present in the client instance or the client crashes (thanks Jorge for finding that).
  The client's eventTalkMyChocobo (the scene right before the naming box), eventAfterChocoboName and eventCancelChocoboName
  all aim the camera at / dress up that actor. It only spawns next to the three city lenders (chocoViews below), so the
  issuance is only offered by a lender standing next to one (a lender in an opening's past city has none: #417).
* eventSetChocoboName returns the typed name; Escape and the Cancel button both return "". Anything that isn't a
  non-blank string is treated as a cancel.
* Special spawn codes must be sent for getting your chocobo or renting for it to work properly.

--]]

require ("global")

-- Retail 800 gil; the host's [economy] chocobo_price_percent scales it.
local retailRentalPrice = 800;
local rentalTime = 10;

local gcIssuances = {
	[1500006] = 2001004,
	[1500061] = 2001005,
	[1000840] = 2001006
};

local startAppearances = {
	[1500006] = CHOCOBO_LIMSA1,
	[1500061] = CHOCOBO_GRIDANIA1,
	[1000840] = CHOCOBO_ULDAH1
};

local cityExits = {
	[1500006] = {133, -6.032, 46.356, 132.572, 3.034},
	[1500061] = {150, 333.271, 5.889, -943.275, 0.794},
	[1000840] = {170, -26.088, 181.846, -79.438, 2.579}
};

-- Where each city's sys_chocoview (class 1080101) stands: zone, x, y, z (server_spawn_locations).
local chocoViews = {
	[1500006] = {133, -436.185, 19.0, 206.26},
	[1500061] = {206, 68.44, 10.87, -1244.42},
	[1000840] = {175, -36.611, 192.037, 18.759}
};

-- The issuance scenes crash the client without a sys_chocoview in the player's
-- instance. Only the public city lenders have one beside them; the same lender
-- class also stands in the openings' past cities (private areas), far from it.
function chocoViewNearby(npc)
	local view = chocoViews[npc:GetActorClassId()];
	if (view == nil) then
		return false;
	end
	local x, y, z, rot, zone = npc:GetPos();
	if (zone ~= view[1] or x == nil) then
		return false;
	end
	local dx, dy, dz = x - view[2], y - view[3], z - view[4];
	return (dx * dx + dy * dy + dz * dz) <= 100; -- within 10 yalms
end

function validChocoboName(name)
	if (type(name) ~= "string") then
		return false;
	end
	local trimmed = name:match("^%s*(.-)%s*$");
	-- The box itself enforces 3-10 characters; bytes here, so leave room for non-ASCII.
	return #trimmed > 0 and #trimmed <= 40;
end

function init(npc)
	return false, false, 0, 0;	
end

function onEventStarted(player, npc, triggerName)	
	local curLevel = 20; -- TODO: pull from character
	local hasIssuance = player:GetItemPackage(INVENTORY_KEYITEMS):HasItem(gcIssuances[npc:GetActorClassId()]);
	local hasChocobo = player.hasChocobo;
	
	if (hasChocobo == false) then -- Let GMs auto have the issuance for debugging 
		hasIssuance = true;
	end

	local canIssue = chocoViewNearby(npc);
	if (not canIssue) then
		hasIssuance = false;
	end

	local rentalPrice = ChocoboPrice(retailRentalPrice);
	local hasFunds = (player:GetCurrentGil() >= rentalPrice);

	callClientFunction(player, "eventTalkWelcome", player);
	
	local menuChoice = callClientFunction(player, "eventAskMainMenu", player, curLevel, hasFunds, hasIssuance, hasChocobo, hasChocobo, 0);

	if (menuChoice == 1 and not canIssue) then -- No sys_chocoview here: the scenes would crash the client
		callClientFunction(player, "eventTalkStepBreak", player);
	elseif (menuChoice == 1) then -- Issuance option

		callClientFunction(player, "eventTalkMyChocobo", player);
		local nameResponse = callClientFunction(player, "eventSetChocoboName", true);

		if (not validChocoboName(nameResponse)) then -- Cancel Chocobo naming (Escape, Cancel, or nothing usable)
			callClientFunction(player, "eventCancelChocoboName", player);
			callClientFunction(player, "eventTalkStepBreak", player);
			player:EndEvent();
			return;
		else		
			local appearance = startAppearances[npc:GetActorClassId()];			
			player:IssueChocobo(appearance, nameResponse:match("^%s*(.-)%s*$"));
			
			callClientFunction(player, "eventAfterChocoboName", player);			

			--Add Chocobo License and remove issuance
			if (player:GetItemPackage(INVENTORY_KEYITEMS):HasItem(2001007) == false) then
				player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(2001007);
			end
			player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(gcIssuances[npc:GetActorClassId()], 1);
			
			--Warp with the special chocobo warp mode.
			mountChocobo(player);			
			GetWorldManager():DoZoneChange(player, cityExits[npc:GetActorClassId()][1], nil, 0, SPAWN_CHOCOBO_GET, cityExits[npc:GetActorClassId()][2], cityExits[npc:GetActorClassId()][3], cityExits[npc:GetActorClassId()][4], cityExits[npc:GetActorClassId()][5]);		
		end
				
	elseif(menuChoice == 2) then -- Summon Bird
		mountChocobo(player);
		GetWorldManager():DoZoneChange(player, cityExits[npc:GetActorClassId()][1], nil, 0, SPAWN_NO_ANIM, cityExits[npc:GetActorClassId()][2], cityExits[npc:GetActorClassId()][3], cityExits[npc:GetActorClassId()][4], cityExits[npc:GetActorClassId()][5]);		
	elseif(menuChoice == 3) then -- Change Barding
		callClientFunction(player, "eventTalkStepBreak", player);
	elseif(menuChoice == 5) then -- Rent Bird
		-- The rental fee (the menu only offers renting when hasFunds).
		if (rentalPrice > 0) then
			player:GetItemPackage(INVENTORY_CURRENCY):RemoveItem(1000001, rentalPrice);
		end
		mountChocobo(player, true, 1);
		GetWorldManager():DoZoneChange(player, cityExits[npc:GetActorClassId()][1], nil, 0, SPAWN_CHOCOBO_RENTAL, cityExits[npc:GetActorClassId()][2], cityExits[npc:GetActorClassId()][3], cityExits[npc:GetActorClassId()][4], cityExits[npc:GetActorClassId()][5]);
	else
		callClientFunction(player, "eventTalkStepBreak", player);
	end

	player:EndEvent();
end

function mountChocobo(player, isRental, rentalMinutes)
	if (isRental) then		
		player:ChangeMusic(64);		
		player:StartChocoboRental(rentalMinutes);
	else
		player:ChangeMusic(83);
	end
	
	player:SendMountAppearance();
	player:SetMountState(1);
	player:ChangeSpeed(0.0, 5.0, 10.0, 10.0);
	player:ChangeState(15);	
end