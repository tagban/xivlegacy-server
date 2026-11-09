require("modifiers")

--Magnitude is the attack Delay multiplier (0.8 = 20% faster swings)
function onGain(owner, effect, actionContainer)
    --A haste with no size would zero the delay and divide by zero when it
    --wears off. Default to 20% faster swings.
    if effect.GetMagnitude() == 0 then
        effect.SetMagnitude(0.8);
    end
    owner.MultiplyMod(modifiersGlobal.Delay, effect.GetMagnitude());
end;

function onLose(owner, effect, actionContainer)
    owner.DivideMod(modifiersGlobal.Delay, effect.GetMagnitude());
end;
