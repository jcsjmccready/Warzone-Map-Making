require('Utilities')

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)
    MigrateModSettings();

    local descriptionVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    UI.CreateLabel(descriptionVGroup).SetText("At the end of the turn, your territories or cities provide a configurable amount of income while under the effect of a Reconnaissance or Surveillance Card.");

    UI.CreateVerticalLayoutGroup(rootParent);

    local modVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(modVGroup).SetText("Mod Behaviour:").SetColor(SUBHEADING_COLOUR);

    if (Mod.Settings.ReconnaissanceEnabled or Mod.Settings.MonitorCities or Mod.Settings.MonitorTerritories) then
        UI.CreateLabel(modVGroup).SetText("Reconnaissance:").SetColor(SUBHEADING_COLOUR2);

        if (Mod.Settings.MonitorCities) then
            if (Mod.Settings.CityIncomeModePerCity) then
                UI.CreateLabel(modVGroup).SetText(Mod.Settings.EffectStrength .. " increased gold per city");
            elseif (Mod.Settings.CityIncomeModePerTerritoryWithCity) then
                UI.CreateLabel(modVGroup).SetText(Mod.Settings.EffectStrength .. " increased gold per territory with a city");
            end
        elseif (Mod.Settings.MonitorTerritories) then
            UI.CreateLabel(modVGroup).SetText(Mod.Settings.EffectStrength .. " increased income per territory");
        end
    end

    if (Mod.Settings.SurveillanceEnabled) then
        UI.CreateLabel(modVGroup).SetText("Surveillance:").SetColor(SUBHEADING_COLOUR2);

        if (Mod.Settings.SurveillanceMonitorCities) then
            if (Mod.Settings.SurveillanceCityIncomeModePerCity) then
                UI.CreateLabel(modVGroup).SetText(Mod.Settings.SurveillanceEffectStrength .. " increased gold per city");
            elseif (Mod.Settings.SurveillanceCityIncomeModePerTerritoryWithCity) then
                UI.CreateLabel(modVGroup).SetText(Mod.Settings.SurveillanceEffectStrength .. " increased gold per territory with a city");
            end
        elseif (Mod.Settings.SurveillanceMonitorTerritories) then
            UI.CreateLabel(modVGroup).SetText(Mod.Settings.SurveillanceEffectStrength .. " increased income per territory");
        end
    end
end
