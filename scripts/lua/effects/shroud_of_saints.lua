require("modifiers")

--Shroud of Saints: half the enmity from your actions, and MP comes back
--while it lasts (2% of max MP every regen tick; the real rate isn't known).
function onGain(owner, effect, actionContainer)
    owner.AddMod(modifiersGlobal.Refresh, math.max(math.floor(owner.GetMaxMP() * 0.02), 1));
end;

function onLose(owner, effect, actionContainer)
end;

function onCommandStart(effect, owner, skill, actionContainer)
    skill.enmityModifier = skill.enmityModifier * 0.5;
end;
