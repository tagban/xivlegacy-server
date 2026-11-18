require("modifiers")

--Shell (Ironwill Unguent): magic defense up. Spell mitigation reads the six
--elemental resistances the way physical mitigation reads Defense, so Shell
--raises each by the same amount Protect gives Defense (4.56 per point).
local ELEMENTS = {
    "FireResistance", "IceResistance", "WindResistance",
    "EarthResistance", "LightningResistance", "WaterResistance",
};

function onGain(owner, effect, actionContainer)
    local buff = 4.56 * effect.GetMagnitude();
    for _, name in ipairs(ELEMENTS) do
        owner.AddMod(modifiersGlobal[name], buff);
    end
end;

function onLose(owner, effect, actionContainer)
    local buff = 4.56 * effect.GetMagnitude();
    for _, name in ipairs(ELEMENTS) do
        owner.SubtractMod(modifiersGlobal[name], buff);
    end
end;
