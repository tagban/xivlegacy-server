require("battleutils")

--Forces crit on attacks made with axes: the marauder's and warrior's own
--commands (class 4, job 17) and auto-attacks.
function onPreAction(effect, caster, target, skill, action, actionContainer)
    if (skill.GetCommandType() == CommandType.AutoAttack or skill.job == 4 or skill.job == 17) then
        --Set action's crit rate to 100%
        action.critRate = 100.0;
    end
end;
