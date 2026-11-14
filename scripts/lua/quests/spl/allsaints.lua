--[[

All Saints' Wake: the numbers and ids Spl0i2 "Impish Impositions", the
guild runners and the trickster imps share, kept in one place so they are
easy to change.

When the event runs:  settings/events.toml ([allsaints]), or `!event`.
                      The imps show only at night, Eorzean time (same file).
Where its NPCs stand: common/sql/data/server_spawn_locations.sql,
                      ids 30910-30921 (tagged in server_spawn_location_events).

Imps broke out of the Marasaja Pit and the Spirithold while their wardens
hid indoors for All Saints' Wake. They disguised themselves as townsfolk
("suspicious ..."), three per city, near guilds and shops, and challenged
the Adventurers' Guild to a contest of riddles. A player on the quest who
talks to an imp gets a riddle: a right answer pays COOKIES_RIGHT Pumpkin
Cookies, a wrong one COOKIES_WRONG (the client's own lines say 9 and 5),
and the imp vanishes for VANISH_SECONDS. The guild runners (Ursielle,
Mudede, Yvane) trade cookies for the pumpkin heads; the first trade
completes the quest, and trading goes on while the event runs.

]]

ALLSAINTS = {
	EVENT			= "allsaints",

	COOKIE			= 3010417,	-- Pumpkin Cookie
	-- Prizes, in the order the client's reward widget lists them, and
	-- their cookie prices (the client's prize line shows these numbers).
	PRIZES			= {8013301, 8013302, 8013303, 8013304},	-- Pumpkin Head, Unripened, White, Ripened
	PRICES			= {3, 10, 50, 99},
	SPL0I2_EXP		= 0,

	COOKIES_RIGHT	= 9,		-- the imp's "right answer" line says 9
	COOKIES_WRONG	= 5,		-- its consolation line says 5
	VANISH_SECONDS	= 900,		-- an imp is gone this long after a riddle (~5 Eorzean hours)

	-- NPCs (actor class ids)
	URSIELLE		= 1001789,	-- Limsa Lominsa
	MUDEDE			= 1001790,	-- Gridania
	YVANE			= 1001791,	-- Ul'dah
};

-- Each runner: the client's city argument (0 Limsa, 1 Gridania, 2 Ul'dah)
-- and the quest offer event.
ALLSAINTS.RUNNERS = {
	[ALLSAINTS.URSIELLE]	= {city = 0, offer = "processEventHWLStart"},
	[ALLSAINTS.MUDEDE]		= {city = 1, offer = "processEventHWGStart"},
	[ALLSAINTS.YVANE]		= {city = 2, offer = "processEventHWUStart"},
};

-- The riddles: the imp's text sheet (PopulaceHalloweenTrans) holds 20, each
-- a question line followed by five answer lines; the first answer listed
-- is the right one. The imp shows the right answer and two wrong ones.
ALLSAINTS.RIDDLES = {};
for k = 0, 19 do
	local q = 29 + 6 * k;
	table.insert(ALLSAINTS.RIDDLES, {question = q, right = q + 1, wrong = {q + 2, q + 3, q + 4, q + 5}});
end

SPL0I2_ID = 110800;

-- The prize exchange at a runner (the client's SUMFES events).
-- `completeQuest`, when given, is called after the first successful
-- trade (the quest's turn-in). Returns true when a prize changed hands.
function allSaintsExchange(player, quest, city, completeQuest)
	local S = ALLSAINTS;
	local choice = callClientFunction(player, "delegateEvent", player, quest, "processEventSUMFES001", 0, city);
	-- 11-14: the player picked prize 1-4 and confirmed (the client adds 10);
	-- anything else (199 declined, 3 or -3 left the menu) trades nothing.
	local pick = (type(choice) == "number") and (choice - 10) or 0;
	if (pick < 1 or pick > #S.PRIZES) then
		return false;
	end
	local prize, price = S.PRIZES[pick], S.PRICES[pick];
	local bag = player:GetItemPackage(INVENTORY_NORMAL);
	if (bag:HasItem(prize, 1)) then
		-- one of each per adventurer
		callClientFunction(player, "delegateEvent", player, quest, "processEventSUMFES005", city);
		return false;
	end
	if (bag:GetItemQuantity(S.COOKIE) < price) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventSUMFES002", city);
		return false;
	end
	bag:RemoveItem(S.COOKIE, price);
	if (completeQuest ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventSUMFES003", city);
	end
	callClientFunction(player, "delegateEvent", player, quest, "processEventSUMFES004", city);
	bag:AddItem(prize, 1, 1);
	if (completeQuest ~= nil) then
		completeQuest();
	end
	return true;
end

-- A runner a player's quest doesn't answer for: someone who finished
-- Spl0i2 keeps trading cookies while the event runs.
function allSaintsRunnerTalk(player, npc)
	local runner = ALLSAINTS.RUNNERS[npc:GetActorClassId()];
	if (runner ~= nil and player:IsQuestCompleted(SPL0I2_ID) and IsSeasonalEventActive(ALLSAINTS.EVENT)) then
		allSaintsExchange(player, GetStaticActor("Spl0i2"), runner.city, nil);
	end
	player:EndEvent();
end

local function pickTwo(list)
	local a = math.random(#list);
	local b = math.random(#list - 1);
	if (b >= a) then b = b + 1; end
	return list[a], list[b];
end

-- A trickster imp (PopulaceHalloweenTrans). A player on the quest, or done
-- with it, unmasks it and gets a riddle; anyone else hears it cackle.
function allSaintsImpTalk(player, npc)
	local S = ALLSAINTS;
	if (not IsSeasonalEventActive(S.EVENT)
		or not (player:HasQuest(SPL0I2_ID) or player:IsQuestCompleted(SPL0I2_ID))) then
		callClientFunction(player, "firstUboa");
		player:EndEvent();
		return;
	end
	local riddle = S.RIDDLES[math.random(#S.RIDDLES)];
	local w1, w2 = pickTwo(riddle.wrong);
	local choices = {riddle.right, w1, w2};
	local right = math.random(3);
	choices[1], choices[right] = choices[right], choices[1];

	callClientFunction(player, "firstTalkNomalEvent", riddle.question);
	local wrong = callClientFunction(player, "firstTalkAskEvent", player, riddle.question,
		choices[1], choices[2], choices[3], right);
	local cookies = (wrong == 0) and S.COOKIES_RIGHT or S.COOKIES_WRONG;
	player:GetItemPackage(INVENTORY_NORMAL):AddItem(S.COOKIE, cookies, 1);
	VanishSeasonalActor(npc.Id, S.VANISH_SECONDS);
	player:EndEvent();
end
