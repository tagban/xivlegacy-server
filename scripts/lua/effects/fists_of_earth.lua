require("modifiers");

-- 1.23b: "Converts your attacks into earth attacks and grants a bonus to
-- physical defense. Effect ends upon reuse. MP is consumed while effect
-- is active." Enhanced Fists of Earth (tier 2) adds 5% to the bonus. The
-- earth conversion isn't modeled; the MP drain rate is a guess.
function onGain(owner, effect, actionContainer)
    local bonus = 0.10;
    if effect.GetTier() == 2 then
        bonus = 0.15;
    end
    owner.AddMod(modifiersGlobal.Defense, math.floor(owner.GetMod(modifiersGlobal.Defense) * bonus));
    owner.SubtractMod(modifiersGlobal.Refresh, 1 + math.floor(owner.GetLevel() / 10));
end;

function onLose(owner, effect, actionContainer)
end;
