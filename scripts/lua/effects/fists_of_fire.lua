require("modifiers");

-- 1.23b: "Converts your attacks into fire attacks and grants a bonus to
-- attack power. Effect ends upon reuse. MP is consumed while effect is
-- active." Enhanced Fists of Fire (tier 2) adds 5% to the bonus. The fire
-- conversion isn't modeled; the MP drain rate is a guess.
function onGain(owner, effect, actionContainer)
    local bonus = 0.10;
    if effect.GetTier() == 2 then
        bonus = 0.15;
    end
    owner.AddMod(modifiersGlobal.Attack, math.floor(owner.GetMod(modifiersGlobal.Attack) * bonus));
    owner.SubtractMod(modifiersGlobal.Refresh, 1 + math.floor(owner.GetLevel() / 10));
end;

function onLose(owner, effect, actionContainer)
end;
