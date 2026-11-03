require("modifiers")
require("battleutils")

--Paralysis: now and then the paralyzed actor's attack or command fails.
--1.0's rate isn't known; 25% like later games.
function onPreAction(effect, caster, target, skill, action, actionContainer)
    if math.random() < 0.25 then
        action.hitRate = 0;
    end
end;
