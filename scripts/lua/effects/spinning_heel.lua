require("modifiers")

-- One more hit per auto-attack (fists 2 -> 3). Relative, so the weapon's
-- own count comes back when it ends; the swing grows by the extra hit's
-- share (auto_attack_hit_multiplier).
function onGain(owner, effect, actionContainer)
    owner.AddMod(modifiersGlobal.HitCount, 1);
end;

function onLose(owner, effect, actionContainer)
    owner.SubtractMod(modifiersGlobal.HitCount, 1);
end;
