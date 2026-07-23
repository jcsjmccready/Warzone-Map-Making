require('Utilities')

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)

    local descriptionVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    UI.CreateLabel(descriptionVGroup).SetText("Playing a Reconnaissance card on a friendly territory grants additional income from the cities/territories under its effect, while the effect lasts.");

    UI.CreateVerticalLayoutGroup(rootParent);

    local modVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(modVGroup).SetText("Mod Behaviour:").SetColor(SUBHEADING_COLOUR);

    if (Mod.Settings.MonitorCities) then
        if (Mod.Settings.CityIncomeModePerCity) then
            UI.CreateLabel(modVGroup).SetText(Mod.Settings.EffectStrength .. " increased gold per city");
        elseif (Mod.Settings.CityIncomeModePerTerritoryWithCity) then
            UI.CreateLabel(modVGroup).SetText(Mod.Settings.EffectStrength .. " increased gold per territory with a city");
        end
    elseif (Mod.Settings.MonitorTerritories) then
        UI.CreateLabel(modVGroup).SetText(Mod.Settings.EffectStrength .. " increased gold/troops per territory");
    end
end