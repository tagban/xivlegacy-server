require("modifiers")
require("battleutils")

-- Stygian Spikes: the 1.23b status text says part of the damage taken goes
-- back to the attacker. No 1.0 numbers are known: a fifth of a melee blow.
function onDamageTaken(effect, attacker, defender, skill, action, actionContainer)
    if skill.GetActionType() == ActionType.Physical then
        local amount = math.max(1, math.floor((action.amount + action.amountMitigated) / 5));
        attacker.DelHP(amount, actionContainer);
        --30350: Counter! You hit target for x points of damage
        actionContainer.AddHitAction(attacker.actorId, 30350, amount);
    end;
end;
