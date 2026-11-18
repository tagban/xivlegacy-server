--[[

Monster Points: earned only by playing as a monster (!monstermode, see
map-server/src/runtime/monster_points.rs), spent here.

Three vendors, each a monster that fits its city, sell level 50 gear for
points (MonsterPointsVendor, called from their scripts under
unique/<zone>/PopulaceShopSalesman/). A client with the XIVLegacy shop patch
gets the shop window (its custom pack lists MP_GOODS in this order); `!mp`
shows the balance and lists and buys the same goods in chat near a vendor.

Prices and the list live here and in the client's pack (keep both in step).

--]]

require("global")

-- The currency item that holds the balance (named "Monster Points" by the
-- client patch) and the client shop pack the patched client knows.
MP_ITEM = 1000124;
MP_SHOP_PACK = 5124;

-- { item id, price } in the client pack's row order.
MP_GOODS = {
    { 8013601, 1500 }, -- Darklight Helm
    { 8013602, 1500 }, -- Darklight Eyepatch
    { 8051502, 1500 }, -- Darklight Breeches
    { 8071502, 1500 }, -- Darklight Gauntlets
    { 8071503, 1500 }, -- Darklight Bracers
    { 8071504, 1500 }, -- Darklight Gloves
    { 8081901, 1500 }, -- Darklight Sollerets
    { 8081902, 1500 }, -- Darklight Caligae
    { 8081903, 1500 }, -- Darklight Boots
    { 8032801, 2500 }, -- Heavy Darklight Armor
    { 8032802, 2500 }, -- Darklight Cuirass
    { 8032803, 2500 }, -- Darklight Corselet
    { 8032804, 2500 }, -- Darklight Cowl
    { 4020112, 5000 }, -- Murderous Mogfists
    { 4030407, 5000 }, -- Morbid Mogblade
    { 4040013, 5000 }, -- Malignant Mogaxe
    { 4070214, 5000 }, -- Mischievous Mogbow
    { 4080212, 5000 }, -- Melancholy Mogfork
    { 5020111, 5000 }, -- Maleficent Mogstaff
    { 5030036, 5000 }, -- Malevolent Mogwand
    { 8013635, 800 },  -- Dalamud Horn
};

-- Names for chat (the window names items itself).
MP_GOOD_NAMES = {
    "Darklight Helm", "Darklight Eyepatch", "Darklight Breeches", "Darklight Gauntlets",
    "Darklight Bracers", "Darklight Gloves", "Darklight Sollerets", "Darklight Caligae",
    "Darklight Boots", "Heavy Darklight Armor", "Darklight Cuirass", "Darklight Corselet",
    "Darklight Cowl", "Murderous Mogfists", "Morbid Mogblade", "Malignant Mogaxe",
    "Mischievous Mogbow", "Melancholy Mogfork", "Maleficent Mogstaff", "Malevolent Mogwand",
    "Dalamud Horn",
};

-- The vendors: where they stand (for `!mp` in chat) and what they say.
MP_VENDORS = {
    qiqirn = {
        name = "Nibbles Coinwhisker",
        zone = 175, x = -64.5, y = 195.2, z = 75.0,
        greetings = {
            "Squeak! Monster Points, monster prizes! Nibbles trades fair, mostly!",
            "You smell like a dodo. Good! Dodo-smell means you've been earning, yes?",
            "Shiny Darklight, sharp Mogblades! Nibbles has them all, for points only.",
            "No gil, no gil! Nibbles only takes Monster Points. Gil is for boring folk.",
        },
        farewell = "Come back with more points! Nibbles will be right here. Probably.",
    },
    moogle = {
        name = "Mogsley Pompomtrade",
        zone = 155, x = 58.5, y = 4.0, z = -1193.5,
        greetings = {
            "Kupo! A fellow monster-at-heart! Let's see those Monster Points, kupo!",
            "The Mogfists are my favorite, kupo. Don't tell the Mogblade.",
            "Every point you earned as a monster counts here, kupo! Even the wobbly ones.",
            "Welcome, welcome! Mind the pompom, kupo. It's very important.",
        },
        farewell = "Kupo-kupo! Go be a fearsome beast and come back soon!",
    },
    goblin = {
        name = "Gobbie Grubtrader",
        zone = 133, x = -436.0, y = 39.6, z = 190.0,
        greetings = {
            "Hey hey! Monster Points for shinies! Best deal in all Limsa, no lie!",
            "You fight like big monster? Good! Gobbie pays in shinies for that.",
            "No haggle! Price is price! ...Okay, price is still price.",
            "Darklight, Mog-weapons, fancy horn. Gobbie has it, you have points?",
        },
        farewell = "Bye bye! Gobbie keeps the shinies warm for you!",
    },
};

-- How close to a vendor `!mp buy` works, in yalms.
MP_NEAR = 8;

local function vendorSay(player, vendor, text)
    player:SendMessage(MESSAGE_TYPE_SAY, vendor.name, text);
end

local function info(player, text)
    player:SendMessage(MESSAGE_TYPE_SYSTEM, "", text);
end

function MonsterPointsBalance(player)
    return player:GetItemPackage(INVENTORY_CURRENCY):GetItemQuantity(MP_ITEM) or 0;
end

-- The vendor `player` is standing near, or nil.
function MonsterPointsNearVendor(player)
    local x, y, z, _, zone = player:GetPos();
    for _, v in pairs(MP_VENDORS) do
        if zone == v.zone then
            local dx, dz = x - v.x, z - v.z;
            if dx * dx + dz * dz <= MP_NEAR * MP_NEAR and math.abs(y - v.y) < 6 then
                return v;
            end
        end
    end
    return nil;
end

-- The goods as chat lines.
function MonsterPointsList(player)
    info(player, string.format("Monster Points: you have %d. The vendors trade:", MonsterPointsBalance(player)));
    for i, g in ipairs(MP_GOODS) do
        info(player, string.format("%2d. %s - %d", i, MP_GOOD_NAMES[i], g[2]));
    end
    info(player, "Near a Monster Points vendor, say !mp buy <number>.");
end

-- Buy row `index` (1-based) of MP_GOODS for Monster Points.
function MonsterPointsBuy(player, index)
    local g = MP_GOODS[index];
    if g == nil then
        info(player, "There is no such item. Say !mp list to see the goods.");
        return false;
    end
    if MonsterPointsBalance(player) < g[2] then
        info(player, string.format("%s costs %d Monster Points; you have %d.",
            MP_GOOD_NAMES[index], g[2], MonsterPointsBalance(player)));
        return false;
    end
    -- Not shop.lua's purchaseItem: it waits for AddItem's result code,
    -- which this server's binding doesn't return, so it never took the
    -- price.
    player:GetItemPackage(INVENTORY_NORMAL):AddItem(g[1], 1, 1);
    player:GetItemPackage(INVENTORY_CURRENCY):RemoveItem(MP_ITEM, g[2]);
    -- You trade <price> <Monster Points> for <1> <item>.
    player:SendGameMessage(player, GetWorldMaster(), 25071, MESSAGE_TYPE_SYSTEM, MP_ITEM, 1, g[1], 1, g[2], 1);
    info(player, string.format("%s is yours. %d Monster Points left.",
        MP_GOOD_NAMES[index], MonsterPointsBalance(player) - g[2]));
    return true;
end

-- A vendor's talk: a greeting, then the shop (the window on the
-- XIVLegacy client, the list in chat otherwise).
function MonsterPointsVendor(player, npc, kind)
    local vendor = MP_VENDORS[kind];
    vendorSay(player, vendor, vendor.greetings[math.random(#vendor.greetings)]);
    if MP_SHOP_WINDOW then
        callClientFunction(player, "openShopBuy", player, MP_SHOP_PACK, MP_ITEM);
        while (true) do
            local row, quantity = callClientFunction(player, "selectShopBuy", player);
            if row == nil or row == 0 then
                callClientFunction(player, "closeShopBuy", player);
                break;
            end
            MonsterPointsBuy(player, row);
        end
    else
        MonsterPointsList(player);
    end
    vendorSay(player, vendor, vendor.farewell);
    callClientFunction(player, "finishTalkTurn", player);
    player:EndEvent();
end

-- Whether vendors open the shop window or list the goods in chat. The
-- window needs pack 5124 from the XIVLegacy client's Monster Points patch
-- (xivlegacy-launcher #34): a client without it crashes when it opens.
-- Turn it on only when every player runs a patched client.
MP_SHOP_WINDOW = false;
