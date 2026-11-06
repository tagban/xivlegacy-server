require("modifiers")
require("battleutils")

-- Attack each Light Shot stack adds, as a share of the archer's Attack when
-- the first stack lands. No 1.0 source gives the size: this is a default
-- (STUCK.md, 2026-11-05) the user can change here. The status magnitude
-- (100, 150 with Enhanced Raging Strike) scales it.
RAGING_STRIKE_ATTACK_PER_STACK = 0.10
RAGING_STRIKE_MAX_STACKS = 3
LIGHT_SHOT = 27259

-- The effect lands at tier 1; each stack adds a tier. The extra holds one
-- stack's Attack.
local function stacks(effect)
    return math.max(effect.GetTier() - 1, 0)
end

function onHit(effect, attacker, defender, skill, action, actionContainer)
    if skill.id ~= LIGHT_SHOT or stacks(effect) >= RAGING_STRIKE_MAX_STACKS then
        return
    end
    if stacks(effect) == 0 or effect.GetExtra() <= 0 then
        local share = RAGING_STRIKE_ATTACK_PER_STACK * effect.GetMagnitude() / 100
        effect.SetExtra(math.max(1, math.floor(attacker.GetMod(modifiersGlobal.Attack) * share + 0.5)))
    end
    effect.SetTier(stacks(effect) + 2)
    attacker.AddMod(modifiersGlobal.Attack, effect.GetExtra())
end

-- A missed Light Shot loses every stack. (The mods hooks add are tracked
-- with the effect, so they also come off when it ends.)
function onMiss(effect, attacker, defender, skill, action, actionContainer)
    if skill.id ~= LIGHT_SHOT or stacks(effect) == 0 then
        return
    end
    attacker.SubtractMod(modifiersGlobal.Attack, effect.GetExtra() * stacks(effect))
    effect.SetTier(1)
end
