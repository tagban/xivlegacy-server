require("modifiers")
require("battleutils")

-- Shock Spikes: electric spikes around the enemy caster that hurt whoever
-- strikes it in melee (the 1.23b status text: they deal lightning damage
-- to attackers). No 1.0 numbers are known: the attacker takes a tenth of
-- the blow, at least 1.
function onDamageTaken(effect, attacker, defender, skill, action, actionContainer)
    if skill.GetActionType() == ActionType.Physical then
        local amount = math.max(1, math.floor((action.amount + action.amountMitigated) / 10));
        attacker.DelHP(amount, actionContainer);
        --30350: Counter! You hit target for x points of damage
        actionContainer.AddHitAction(attacker.actorId, 30350, amount);
    end;
end;
