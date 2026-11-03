require("modifiers")
require("battleutils")

--Presence of Mind: better evasion against attacks from the side or behind.
--The size isn't known; 20 points off the attacker's hit rate.
function onPreAction(effect, caster, target, skill, action, actionContainer)
    if action.param ~= HitDirection.Front then
        action.hitRate = math.max(action.hitRate - 20, 0);
    end
end;
