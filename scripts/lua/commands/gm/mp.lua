require("global");
require("monsterpoints");

properties = {
    permissions = 0,
    parameters = "ss",
    description =
[[
Monster Points: your balance, the vendors' goods, and buying near a vendor.
!mp |
!mp list |
!mp buy <number> |
]],
}

function onTrigger(player, argc, verb, number)
    verb = verb and string.lower(verb) or "";
    if verb == "" then
        player:SendMessage(MESSAGE_TYPE_SYSTEM, "", string.format(
            "You have %d Monster Points. Earn them as a monster; spend them with Nibbles in Ul'dah, Mogsley in Gridania or Gobbie in Limsa Lominsa. !mp list shows the goods.",
            MonsterPointsBalance(player)));
    elseif verb == "list" then
        MonsterPointsList(player);
    elseif verb == "buy" then
        local index = tonumber(number);
        if index == nil then
            player:SendMessage(MESSAGE_TYPE_SYSTEM, "", "Say !mp buy <number>; !mp list shows the numbers.");
        elseif MonsterPointsNearVendor(player) == nil then
            player:SendMessage(MESSAGE_TYPE_SYSTEM, "", "Stand by a Monster Points vendor to buy.");
        else
            MonsterPointsBuy(player, index);
        end
    else
        player:SendMessage(MESSAGE_TYPE_SYSTEM, "", "Say !mp, !mp list or !mp buy <number>.");
    end
end
