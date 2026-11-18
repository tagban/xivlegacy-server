require("modifiers")

--Increases block rate by 100%
function onGain(owner, effect, actionContainer)
    owner.AddMod(modifiersGlobal.RawBlockRate, 100);
end

function onLose(owner, effect, actionContainer)
    owner.SubtractMod(modifiersGlobal.RawBlockRate, 100);
end

--Applys Divine Regen to party in range when healed by cure or cura
function onHealed(effect, caster, target, skill, action, actionContainer)
    --             cure                  cura
    if (skill.id == 27346 or skill.id == 27347) and (caster.actorId ~= target.actorId) then
        local regenDuration = 30;
        --Apparently heals for 85 without AF, 113 with. Unsure if these can be improved with stats
        local magnitude = 85

        --Need a better way to set magnitude when adding effects
        if effect.GetTier() == 2 then
            magnitude = 113;
        end

        --Every party member within 8 yalms of the target gets Divine Regen
        --(the server walks the party once no actor is locked)
        target.AddPartyStatusEffect(8, 223264, effect.GetTier(), magnitude, regenDuration);
    end
end;