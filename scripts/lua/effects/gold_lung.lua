require("modifiers")

-- Gold Lung (Aurum Vale gas). The server stacks it: each breath of the gold
-- gas re-applies it with one more stack (the tier) and a bigger magnitude,
-- the HP lost per tick (runtime/aurum_hazards.rs).
function onGain(owner, effect, actionContainer)
    owner.AddMod(modifiersGlobal.RegenDown, effect.GetMagnitude());
end

function onLose(owner, effect, actionContainer)
    owner.SubtractMod(modifiersGlobal.RegenDown, effect.GetMagnitude());
end
