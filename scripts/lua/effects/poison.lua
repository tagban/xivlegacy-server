require("modifiers")

function onGain(owner, effect, actionContainer)
    --Monster moves (Digestive Ooze, Queasy Cloud...) don't set a size.
    --Default to half the owner's level in HP per tick (25 at 50).
    if effect.GetMagnitude() == 0 then
        effect.SetMagnitude(math.max(1, math.floor(owner.GetLevel() / 2)));
    end
    owner.AddMod(modifiersGlobal.RegenDown, effect.GetMagnitude());
end

function onLose(owner, effect, actionContainer)
    owner.SubtractMod(modifiersGlobal.RegenDown, effect.GetMagnitude());
end
