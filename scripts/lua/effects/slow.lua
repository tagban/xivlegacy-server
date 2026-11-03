require("modifiers")

--Set magnitude to milliseconds that HF will reduce delay by
function onGain(owner, effect, actionContainer)
    owner.MultiplyMod(modifiersGlobal.Delay, effect.GetMagnitude());
end;

function onLose(owner, effect, actionContainer)
    owner.DivideMod(modifiersGlobal.Delay, effect.GetMagnitude());
end;