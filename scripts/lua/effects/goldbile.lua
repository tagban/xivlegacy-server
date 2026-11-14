require("modifiers")

-- Goldbile (Aurum Vale pools): a poison renewed while you stand in a pool.
-- The magnitude is the HP lost per tick (runtime/aurum_hazards.rs).
function onGain(owner, effect, actionContainer)
    owner.AddMod(modifiersGlobal.RegenDown, effect.GetMagnitude());
end

function onLose(owner, effect, actionContainer)
    owner.SubtractMod(modifiersGlobal.RegenDown, effect.GetMagnitude());
end
