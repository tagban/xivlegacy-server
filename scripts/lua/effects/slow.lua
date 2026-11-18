require("modifiers")

--Set magnitude to milliseconds that HF will reduce delay by
function onGain(owner, effect, actionContainer)
    --Monster moves (Sticky Web) don't set a size; a 0 would zero the delay
    --and divide by zero when it wears off. Default to 25% slower swings.
    if effect.GetMagnitude() == 0 then
        effect.SetMagnitude(1.25);
    end
    owner.MultiplyMod(modifiersGlobal.Delay, effect.GetMagnitude());
end;

function onLose(owner, effect, actionContainer)
    owner.DivideMod(modifiersGlobal.Delay, effect.GetMagnitude());
end;
