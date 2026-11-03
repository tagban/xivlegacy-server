require("modifiers")

function onGain(owner, effect, actionContainer)
    --Flash, Concussive Blow and Gloom Arrow don't set a size. Default to the
    --owner's level (50 accuracy at 50, a quarter fewer hits).
    if effect.GetMagnitude() == 0 then
        effect.SetMagnitude(owner.GetLevel());
    end
    owner.SubtractMod(modifiersGlobal.Accuracy, effect.GetMagnitude());
end;

function onLose(owner, effect, actionContainer)
    owner.AddMod(modifiersGlobal.Accuracy, effect.GetMagnitude());
end;
