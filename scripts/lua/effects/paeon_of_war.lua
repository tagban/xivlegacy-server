require("modifiers")

function onGain(owner, effect, actionContainer)
    --Only one song per bard: the server takes the bard's old song off first
    owner.AddMod(modifiersGlobal.Regain, effect.GetMagnitude());
end;

function onLose(owner, effect, actionContainer)
    owner.SubtractMod(modifiersGlobal.Regain, effect.GetMagnitude());
end;