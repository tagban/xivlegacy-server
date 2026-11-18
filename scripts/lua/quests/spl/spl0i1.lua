require ("global")
require ("quest")
require ("quests/spl/moonfire")

--[[

Quest Script

Name: 	The Heat Is On
Code: 	Spl0i1
Id: 	110799
Prereq: none. Seasonal: Moonfire Faire (settings/events.toml).

The 2011 faire (Firefall Faire in 1.0). See quests/spl/moonfire.lua for the
story and the numbers.

The client's events (city argument 0 Limsa Lominsa, 1 Gridania, 2 Ul'dah):
processEventSUMFESStart (the offer; 1 = signed up), processEventSUMFES001
(the chaperone: the reward list returns 101-107 once the player confirms,
the uniform menu 111-113 for red, blue, green ash), SUMFES002 (no ash),
SUMFES003 (the quest done), SUMFES004 (a reward), SUMFES005 (already have it), and the
cadets' processEventSUMFESGAME001 (here is the ash) and GAME002 (burst
another Bombard first).

]]

local M = MOONFIRE;

SEQ_000				= 0;	-- Burst Bombards in the field; trade their ash.

FLAG_PENDING		= 0;	-- flags 0-3: a Bombard burst at site 1-4, ash not yet collected

local function event(player, quest, name, ...)
	return callClientFunction(player, "delegateEvent", player, quest, name, ...);
end

local function hasUniform(player)
	return moonfireHasAny(player, moonfireSuit(player, "lunar"));
end

local function chaperoneTalk(player, quest, city)
	local choice = event(player, quest, "processEventSUMFES001", 0, city, hasUniform(player) and 1 or 0);
	local pick = type(choice) == "number" and choice - M.REWARD_PICK_BASE or nil;
	local reward = pick ~= nil and M.FIREWORKS[pick] or nil;
	if (reward ~= nil) then
		if (moonfireBag(player):HasItem(reward.item, 1) and pick > 3) then
			event(player, quest, "processEventSUMFES005", city);
		elseif (not moonfireHasAll(player, reward.cost)) then
			event(player, quest, "processEventSUMFES002", city);
		else
			moonfireTake(player, reward.cost);
			moonfireGive(player, {reward.item});
			-- a large firework earns the summer suit of its color
			if (reward.suit ~= nil and not moonfireHasAny(player, moonfireSuit(player, reward.suit))) then
				moonfireGive(player, moonfireSuit(player, reward.suit));
			end
			if (reward.item == M.AZEYMAS_CANDLE) then
				-- the grandest firework: the quest is done
				event(player, quest, "processEventSUMFES003", city);
				event(player, quest, "processEventSUMFES004", city);
				return true;
			end
			event(player, quest, "processEventSUMFES004", city);
		end
		return false;
	end
	-- the uniform menu: a lost Lunar suit back for one pinch of the ash picked
	local ash = type(choice) == "number" and M.UNIFORM_ASH[choice - M.UNIFORM_PICK_BASE] or nil;
	if (ash ~= nil) then
		if (hasUniform(player)) then
			event(player, quest, "processEventSUMFES005", city);
		elseif (not moonfireBag(player):HasItem(ash, 1)) then
			event(player, quest, "processEventSUMFES002", city);
		else
			moonfireTake(player, {[ash] = 1});
			moonfireGive(player, moonfireSuit(player, "lunar"));
			event(player, quest, "processEventSUMFES004", city);
		end
	end
	return false;
end

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	for city, c in pairs(M.CHAPERONES_2011) do
		quest:SetENpc(c, sequence == SEQ_ACCEPT and QFLAG_TALK or QFLAG_REWARD);
	end
	if (sequence == SEQ_ACCEPT) then
		return;
	end
	local data = quest:GetData();
	for i, s in ipairs(M.SITES_2011) do
		quest:SetENpc(s.officer, data:GetFlag(FLAG_PENDING + i - 1) and QFLAG_REWARD or QFLAG_NONE);
	end
	-- the Bombards answer the dance
	quest:SetENpc(M.BOMBARD_2011, QFLAG_NONE, false, false, true);
end

function onTalk(player, quest, npc, eventName)
	local classId = npc:GetActorClassId();
	local cast = M.CAST[classId];

	if (quest:GetSequence() == SEQ_ACCEPT) then
		if (cast ~= nil and cast.role == "chaperone" and cast.year == 2011
			and IsSeasonalQuestOpen(quest:GetQuestId())
			and event(player, quest, "processEventSUMFESStart", cast.city) == 1) then
			player:AcceptQuest(quest);
			moonfireGive(player, moonfireSuit(player, "lunar"));
		end
		player:EndEvent();
		return;
	end

	local done = false;
	if (cast ~= nil and cast.role == "chaperone" and cast.year == 2011) then
		done = chaperoneTalk(player, quest, cast.city);
	else
		local i, site = moonfireSite2011(player);
		if (site ~= nil and classId == site.officer) then
			local data = quest:GetData();
			if (data:GetFlag(FLAG_PENDING + i - 1)) then
				event(player, quest, "processEventSUMFESGAME001", 0, 1, site.variant);
				moonfireBag(player):AddItem(site.ash, M.ASH_2011, 1);
				data:ClearFlag(FLAG_PENDING + i - 1);
			else
				event(player, quest, "processEventSUMFESGAME002", site.variant);
			end
		end
	end
	player:EndEvent();
	if (done) then
		player:CompleteQuest(quest);
	else
		quest:UpdateENPCs();
	end
end

-- /dance at a Bombard: it bursts in a shower of sparks.
function onEmote(player, quest, npc, eventName)
	local i, site = moonfireSite2011(player);
	if (site ~= nil and npc:GetActorClassId() == M.BOMBARD_2011) then
		player:DoEmote(npc.Id, M.DANCE_DO_EMOTE, M.DANCE_MOTION);
		quest:GetData():SetFlag(FLAG_PENDING + i - 1);
	end
	player:EndEvent();
	quest:UpdateENPCs();
end

function getJournalInformation(player, quest)
end

function getJournalMapMarkerList(player, quest)
end
