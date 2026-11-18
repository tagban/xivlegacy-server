require("modifiers")

-- Burn: an enemy caster's fire damage over time (the 1.23b client's own
-- status: fire magic defense lowered, fire damage each tick). No 1.0 tick
-- size is known; like poison, half the owner's level in HP per tick.
function onGain(owner, effect, actionContainer)
    if effect.GetMagnitude() == 0 then
        effect.SetMagnitude(math.max(1, math.floor(owner.GetLevel() / 2)));
    end
    owner.AddMod(modifiersGlobal.RegenDown, effect.GetMagnitude());
end

function onLose(owner, effect, actionContainer)
    owner.SubtractMod(modifiersGlobal.RegenDown, effect.GetMagnitude());
end
