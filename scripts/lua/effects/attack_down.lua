require("modifiers")

function onGain(owner, effect, actionContainer)
    owner.SubtractMod(modifiersGlobal.Attack, effect.GetMagnitude());
end

function onLose(owner, effect, actionContainer)
    owner.AddMod(modifiersGlobal.Attack, effect.GetMagnitude());
end
