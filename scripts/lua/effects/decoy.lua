require("modifiers")
require("battleutils")

--This is the untraited version of decoy.
function onPreAction(effect, caster, target, skill, action, actionContainer)
    --Evade single ranged or magic attack
    --Traited allows for physical attacks
    if target.allegiance ~= caster.allegiance and (skill.isRanged or skill.GetActionType() == ActionType.Magic) then
        --Unsure if decoy forces a miss/resist or if this is the one case where the evade hittype is used
        --Set action's hit rate to 0
        action.hitRate = 0.0;
        --Resist rates are percent and halve each roll: 1600 is a sure
        --full resist (750 left a triple resist, with damage, 6% of the time)
        action.resistRate = 1600;
        --Remove status and add message 
        target.statusEffects.RemoveStatusEffect(effect, actionContainer, 30331, false);
    end

end;