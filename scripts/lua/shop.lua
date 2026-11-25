--[[

Shop Buy/Sell Functions

--]]

-- What each shop visit has spent so far, by currency. The balance HasItem
-- reads is the one the visit started with, so without this a second buy
-- in the same visit passed the check on money already spent (and
-- RemoveItem only takes what is there). Keyed weakly by the visit's player
-- object, so a new visit starts from zero.
local spentThisVisit = setmetatable({}, { __mode = "k" });

function purchaseItem(player, location, itemId, quantity, quality, price, currency)
    
    local worldMaster = GetWorldMaster();          
    local invCheck = -1;
    local spent = spentThisVisit[player] or {};
    spentThisVisit[player] = spent;

    -- Gil prices follow the host's [economy] shop_price_percent (retail 100).
    -- (ShopBuyPrice is the map server's; bare test harnesses lack it.)
    if (currency == 1000001 and itemId ~= 1000001 and ShopBuyPrice ~= nil) then
        price = ShopBuyPrice(itemId, price, quantity);
    end

    if (player:GetItemPackage(INVENTORY_CURRENCY):HasItem(currency, price + (spent[currency] or 0))) then
        invCheck = player:GetItemPackage(location):AddItem(itemId, quantity, quality); 
    
        if (invCheck == INV_ERROR_FULL) then
            -- Your inventory is full.
            player:SendGameMessage(player, worldMaster, 60022, MESSAGE_TYPE_SYSTEM);
        elseif (invCheck == INV_ERROR_ALREADY_HAS_UNIQUE) then
            -- You cannot have more than one <itemId> <quality> in your possession at any given time.
            player:SendGameMessage(player, worldMaster, 40279, MESSAGE_TYPE_SYSTEM, itemId, quality);
        elseif (invCheck == INV_ERROR_SYSTEM_ERROR) then
            player:SendMessage(0x20, "", "[DEBUG] Server Error on adding item.");
        elseif (invCheck == INV_ERROR_SUCCESS) then
            player:GetItemPackage(INVENTORY_CURRENCY):RemoveItem(currency, price);
            spent[currency] = (spent[currency] or 0) + price;
            
            if (currency == 1000001) then  -- If Gil
                -- You purchase <quantity> <itemId> <quality> for <price> gil.
                player:SendGameMessage(player, worldMaster, 25061, MESSAGE_TYPE_SYSTEM, itemId, quality, quantity, price); 
            
            elseif (currency == 1000201 or currency == 1000202 or currency == 1000203) then  -- If Grand Company seal
                -- You exchange <quantity> <GC seals> for <quantity> <itemId> <quality>.
                player:SendGameMessage(player, worldMaster, 25275, MESSAGE_TYPE_SYSTEM, itemId, quality, quantity, price, player.gcCurrent);
                
            elseif (currency >= 1000101 and currency <= 1000123) then -- If Guild mark
                -- You trade <quantity> <itemId> <quality> for <quantity> <itemId> <quality>.
                player:SendGameMessage(player, GetWorldMaster(), 25071, MESSAGE_TYPE_SYSTEM, currency, 1, itemId, 1, price, quantity);
            end 
        end
    else
        -- You do not have enough gil.  (Should never see this)
        player:SendGameMessage(player, worldMaster, 25065, MESSAGE_TYPE_SYSTEM);
    end
    return
end


function sellItem(player, itemId, quantity, quality, itemPrice, slot, currency)
    local worldMaster = GetWorldMaster();
    local cost = quantity * itemPrice;
    
    player:GetItemPackage(INVENTORY_CURRENCY):AddItem(currency, cost);
    player:GetItemPackage(INVENTORY_NORMAL):RemoveItemAtSlot(slot, quantity);   
    -- You sell <quantity> <itemId> <quality> for <cost> gil.
    player:SendGameMessage(player, worldMaster, 25075, MESSAGE_TYPE_SYSTEM, itemId, quality, quantity, cost);
end